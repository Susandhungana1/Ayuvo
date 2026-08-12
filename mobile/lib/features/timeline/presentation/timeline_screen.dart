/// Everything on the record, in the order it happened.
///
/// The four things a patient records live on four screens; this is the one
/// place they are one story. The server pre-formats the titles and descriptions
/// (see `timeline.py`), so this screen's job is grouping, ordering and making
/// the four kinds distinguishable at a glance — not composing sentences.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/time/medi_time.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/states.dart';
import '../domain/timeline_event.dart';
import 'timeline_controller.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(timelineProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.timelineTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(timelineProvider.notifier).refresh(),
        child: switch (timeline) {
          AsyncData(:final value) when value.events.isEmpty => const _Empty(),
          AsyncData(:final value) => _Rail(state: value),
          AsyncError(:final error) => ListView(
              padding: AppSpacing.screen,
              children: [
                ErrorView(
                  error: error,
                  onRetry: () => ref.read(timelineProvider.notifier).refresh(),
                ),
              ],
            ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({required this.state});

  final TimelineState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(timelineDaysProvider);

    // Flattened before building so `ListView.builder` still only builds what is
    // on screen — a five-year record is thousands of rows.
    final rows = <Widget>[
      _Intro(total: state.total),
      for (final day in days) ...[
        _DayHeading(day: day),
        for (final event in day.events)
          _EventRow(key: ValueKey(event.rowKey), event: event),
        const SizedBox(height: AppSpacing.lg),
      ],
      _Footer(state: state),
    ];

    return ListView.builder(
      padding: AppSpacing.screen,
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Text(
        '${context.l10n.timelineSubtitle} · ${context.l10n.timelineEventCount(total)}',
        style: context.texts.bodyMedium
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.day});

  final TimelineDay day;

  @override
  Widget build(BuildContext context) {
    final when = day.day;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        // A row whose timestamp the server could not write gets an honest
        // heading rather than being filed under today.
        when == null ? 'Date unknown' : MediTime.day(when),
        style: context.texts.titleMedium,
      ),
    );
  }
}

/// One event, on the rail.
///
/// The rail is drawn as a positioned line behind the card rather than as a
/// stretched Row child: a `Row` with `CrossAxisAlignment.stretch` inside a
/// scroll view has no height to stretch to, and `IntrinsicHeight` would measure
/// every card twice for a decoration.
class _EventRow extends StatelessWidget {
  const _EventRow({super.key, required this.event});

  final TimelineEvent event;

  static const _railWidth = 28.0;

  @override
  Widget build(BuildContext context) {
    final tone = _toneOf(context, event.kind);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 5,
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: context.colors.outlineVariant),
          ),
          PositionedDirectional(
            start: 0,
            top: AppSpacing.lg,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: tone,
                shape: BoxShape.circle,
                // A 2px ring in the surface colour so the dot reads as sitting
                // on the line rather than being swallowed by it.
                border: Border.all(color: context.colors.surface, width: 2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: _railWidth),
            child: Card(
              child: Padding(
                padding: AppSpacing.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap, not Row: at 2× text "Appointment" and a timestamp
                    // together are wider than the card.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _KindBadge(kind: event.kind, tone: tone),
                        if (event.when case final moment?)
                          Text(
                            MediTime.time(moment),
                            style: context.texts.bodySmall
                                ?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(event.headline, style: context.texts.titleMedium),
                    if (event.description?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        event.description!.trim(),
                        style: context.texts.bodyMedium
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One validated series colour per kind, in a fixed slot order. Never a
  /// generated hue, and never one of the reserved status colours — a report is
  /// not "good" or "critical".
  static Color _toneOf(BuildContext context, TimelineKind kind) {
    final series = context.chart.series;
    return switch (kind) {
      TimelineKind.report => series[0],
      TimelineKind.medicine => series[1],
      TimelineKind.appointment => series[2],
      TimelineKind.vital => series[3],
      TimelineKind.other => context.colors.onSurfaceVariant,
    };
  }
}

/// Colour alone never carries the kind — the word is always there too, which is
/// what makes the four dots readable to someone who cannot tell them apart.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.tone});

  final TimelineKind kind;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      TimelineKind.report => context.l10n.timelineTypeReport,
      TimelineKind.medicine => context.l10n.timelineTypeMedicine,
      TimelineKind.appointment => context.l10n.timelineTypeAppointment,
      TimelineKind.vital => context.l10n.timelineTypeVital,
      TimelineKind.other => '—',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        // Flexible, not a bare Text: "APPOINTMENT" at 2× is wider than the
        // card this badge sits in, and a Row hands a non-flex child whatever
        // width it asks for rather than making it wrap.
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: context.texts.labelSmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state});

  final TimelineState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Center(
          child: Text(
            context.l10n.timelineAllLoaded,
            style: context.texts.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        children: [
          if (state.moreFailed case final error?) ...[
            ErrorView(error: error),
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.loadingMore)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            OutlinedButton(
              onPressed: () => ref.read(timelineProvider.notifier).loadMore(),
              child: Text(context.l10n.timelineLoadMore),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        EmptyState(
          icon: Icons.timeline_outlined,
          title: context.l10n.timelineEmptyTitle,
          message: context.l10n.timelineEmptyBody,
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screen,
      children: const [
        Skeleton(width: 140, height: 20),
        SizedBox(height: AppSpacing.lg),
        SkeletonCard(lines: 2),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 3),
        SizedBox(height: AppSpacing.md),
        SkeletonCard(lines: 2),
      ],
    );
  }
}
