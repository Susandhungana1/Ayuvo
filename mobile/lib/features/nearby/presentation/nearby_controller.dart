/// The map's state: where we are, and what is around us.
///
/// Two steps that fail independently. A denied location still produces a
/// usable map centred on Kathmandu; a dead Overpass mirror still produces a map
/// with the user's own pin on it. Neither failure is allowed to blank the
/// screen, so the fix and the places are separate fields rather than one
/// AsyncValue.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/location_source.dart';
import '../data/overpass_repository.dart';
import '../domain/nearby_place.dart';

@immutable
class NearbyState {
  const NearbyState({
    required this.fix,
    this.places = const [],
    this.loadingPlaces = true,
    this.placesFailed = false,
  });

  final LocationFix fix;
  final List<NearbyPlace> places;
  final bool loadingPlaces;

  /// Every mirror refused. Not an exception on screen — a map that says
  /// "the data service is busy" is more useful than an error card.
  final bool placesFailed;

  LatLng get centre => fix.position;

  bool get isEmpty => !loadingPlaces && !placesFailed && places.isEmpty;
}

final nearbyProvider =
    AsyncNotifierProvider<NearbyController, NearbyState>(NearbyController.new);

class NearbyController extends AsyncNotifier<NearbyState> {
  bool _alive = true;

  @override
  Future<NearbyState> build() async {
    _alive = true;
    ref.onDispose(() => _alive = false);

    // The fix comes first and on its own: the map should appear and be
    // pannable while Overpass is still thinking.
    final fix = await ref.read(locationSourceProvider).current();
    _loadPlaces(fix);
    return NearbyState(fix: fix);
  }

  /// Asks for a location again — after the user has granted the permission in
  /// system settings, where nothing in the app knows it changed.
  Future<void> relocate() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> retryPlaces() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      NearbyState(fix: current.fix, loadingPlaces: true),
    );
    await _loadPlaces(current.fix);
  }

  Future<void> _loadPlaces(LocationFix fix) async {
    try {
      final places = await ref.read(overpassRepositoryProvider).around(fix.position);
      if (!_alive) return;
      state = AsyncData(
        NearbyState(fix: fix, places: places, loadingPlaces: false),
      );
    } catch (error) {
      debugPrint('Nearby lookup failed: $error');
      if (!_alive) return;
      state = AsyncData(
        NearbyState(fix: fix, loadingPlaces: false, placesFailed: true),
      );
    }
  }
}
