/// Hospitals, clinics and pharmacies within 4 km.
///
/// The one screen in the app with no MediStore endpoint behind it: the tiles
/// come from OpenStreetMap and the places from Overpass. Two consequences
/// follow, and both are visible on screen — the "© OpenStreetMap contributors"
/// line is required by the ODbL and is not decoration, and a failure here says
/// the map service is busy rather than blaming the user's connection.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../data/location_source.dart';
import '../domain/nearby_place.dart';
import 'nearby_controller.dart';

class NearbyScreen extends ConsumerWidget {
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby = ref.watch(nearbyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nearbyTitle)),
      body: switch (nearby) {
        AsyncData(:final value) => _Nearby(state: value),
        AsyncError(:final error) => ListView(
            padding: AppSpacing.screen,
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.read(nearbyProvider.notifier).relocate(),
              ),
            ],
          ),
        _ => _Locating(),
      },
    );
  }
}

class _Locating extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screen,
      children: [
        Text(
          context.l10n.nearbyLocating,
          style: context.texts.bodyMedium
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        const Skeleton(width: double.infinity, height: 260),
      ],
    );
  }
}

class _Nearby extends ConsumerWidget {
  const _Nearby({required this.state});

  final NearbyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Map on top, list below — the list is scrollable and the map is not, so
    // they cannot share one scroll view without the map eating drag gestures.
    return Column(
      children: [
        SizedBox(height: 260, child: _Map(state: state)),
        _StatusLine(state: state),
        const Divider(height: 1),
        Expanded(child: _Places(state: state)),
      ],
    );
  }
}

class _Map extends StatelessWidget {
  const _Map({required this.state});

  final NearbyState state;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: state.centre,
        initialZoom: 14,
        // No rotation: a rotated map with no compass is a map nobody can get
        // back to north.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // OSM's tile usage policy requires an identifiable agent. A generic
          // Dart user agent is the kind of thing that gets an app blocked.
          userAgentPackageName: 'com.medistore.app',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: state.centre,
              width: 18,
              height: 18,
              child: Tooltip(
                message: context.l10n.nearbyYouAreHere,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.surface, width: 3),
                  ),
                ),
              ),
            ),
            for (final place in state.places)
              Marker(
                point: place.position,
                width: 26,
                height: 26,
                child: _Pin(kind: place.kind),
              ),
          ],
        ),
        // Required by the ODbL. Not removable, and not shrunk to nothing.
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            color: context.colors.surface.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Text(
              context.l10n.nearbyAttribution,
              style: context.texts.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}

/// Colour and a letter, never colour alone — three pin colours on a busy map
/// are exactly the case where a colour-blind reader is left guessing.
class _Pin extends StatelessWidget {
  const _Pin({required this.kind});

  final PlaceKind kind;

  @override
  Widget build(BuildContext context) {
    final (colour, symbol) = _styleFor(context, kind);
    return Container(
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        symbol,
        style: context.texts.labelSmall?.copyWith(
          color: context.colors.surface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

(Color, String) _styleFor(BuildContext context, PlaceKind kind) => switch (kind) {
      // Not the reserved status colours: a hospital is not an "alert". These
      // are the validated categorical series, used as identity.
      PlaceKind.hospital => (context.chart.series[2], 'H'),
      PlaceKind.clinic => (context.chart.series[3], 'C'),
      PlaceKind.pharmacy => (context.chart.series[0], 'P'),
    };

String _labelFor(BuildContext context, PlaceKind kind) => switch (kind) {
      PlaceKind.hospital => context.l10n.nearbyKindHospital,
      PlaceKind.clinic => context.l10n.nearbyKindClinic,
      PlaceKind.pharmacy => context.l10n.nearbyKindPharmacy,
    };

class _StatusLine extends ConsumerWidget {
  const _StatusLine({required this.state});

  final NearbyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (state.fix.origin) {
      LocationOrigin.device => context.l10n.nearbyShowingYours,
      LocationOrigin.denied => context.l10n.nearbyDenied,
      LocationOrigin.unavailable => context.l10n.nearbyUnavailable,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: context.texts.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          if (!state.fix.isReal)
            TextButton(
              onPressed: () => ref.read(nearbyProvider.notifier).relocate(),
              child: Text(context.l10n.nearbyUseMyLocation),
            ),
        ],
      ),
    );
  }
}

class _Places extends ConsumerWidget {
  const _Places({required this.state});

  final NearbyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadingPlaces) {
      return ListView(
        padding: AppSpacing.screen,
        children: const [
          SkeletonCard(lines: 1),
          SizedBox(height: AppSpacing.md),
          SkeletonCard(lines: 1),
        ],
      );
    }

    if (state.placesFailed) {
      return ListView(
        padding: AppSpacing.screen,
        children: [
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.nearbyFailed,
                    style: context.texts.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.read(nearbyProvider.notifier).retryPlaces(),
                      child: Text(context.l10n.retry),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (state.places.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.xl),
          EmptyState(
            icon: Icons.location_off_outlined,
            title: context.l10n.nearbyNone,
            message: context.l10n.nearbyShowingYours,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: AppSpacing.screen,
      itemCount: state.places.length,
      itemBuilder: (context, index) => _PlaceRow(
        key: ValueKey(state.places[index].id),
        place: state.places[index],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({super.key, required this.place});

  final NearbyPlace place;

  @override
  Widget build(BuildContext context) {
    final (colour, symbol) = _styleFor(context, place.kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: colour,
            radius: 14,
            child: Text(
              symbol,
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.surface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(place.name),
          subtitle: Text(
            '${_labelFor(context, place.kind)} · '
            '${context.l10n.nearbyDistanceKm(place.distanceLabel)}',
          ),
          trailing: TextButton(
            onPressed: () => _openDirections(context),
            child: Text(context.l10n.nearbyDirections),
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(
      place.directions,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No app on this phone can open a map.')),
      );
    }
  }
}
