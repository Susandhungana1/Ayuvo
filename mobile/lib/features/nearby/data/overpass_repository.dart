/// Nearby care, from OpenStreetMap.
///
/// **Deliberately not through `ApiClient`.** This is a third-party service on a
/// different origin, and it must never see a Ayuvo bearer token. It gets
/// its own dio with no interceptors, so a 401 from a busy Overpass mirror can
/// never sign anyone out of Ayuvo.
///
/// Overpass is a free public service run on donated hardware. It rate-limits,
/// it returns 429 and 504 under load, and any given mirror is sometimes simply
/// down — which is why the web app tries three in order and so does this. A
/// failure here is normal operation, not a bug.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../domain/nearby_place.dart';

/// In the order the web app tries them.
const overpassMirrors = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];

/// Every mirror refused. Distinguished from a generic failure so the screen can
/// say what actually happened rather than blaming the user's connection.
class OverpassUnreachable implements Exception {
  const OverpassUnreachable();

  @override
  String toString() => 'OverpassUnreachable';
}

/// The dio Overpass calls go through. Overridden in tests; never shared with
/// the Ayuvo client.
final overpassDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      // Overpass answers a 4 km amenity query in a second or two when healthy
      // and hangs when it is not. Twelve seconds is long enough for the former
      // and short enough that three mirrors still fail inside a minute.
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      responseType: ResponseType.json,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final overpassRepositoryProvider = Provider<OverpassRepository>(
  (ref) => OverpassRepository(ref.watch(overpassDioProvider)),
);

class OverpassRepository {
  const OverpassRepository(this._dio);

  final Dio _dio;

  /// Hospitals, clinics and pharmacies within [nearbyRadiusMetres] of [centre],
  /// nearest first.
  Future<List<NearbyPlace>> around(LatLng centre) async {
    final body = 'data=${Uri.encodeQueryComponent(_query(centre))}';

    for (final mirror in overpassMirrors) {
      try {
        final response = await _dio.post<Object?>(
          mirror,
          data: body,
          options: Options(
            contentType: 'application/x-www-form-urlencoded',
            // A mirror under load answers 429 or 504; treat those as "try the
            // next one" rather than letting dio throw out of the loop.
            validateStatus: (_) => true,
          ),
        );
        if (response.statusCode != 200) continue;

        final data = response.data;
        if (data is! Map) continue;
        return _placesFrom(data['elements'], centre);
      } catch (error) {
        debugPrint('Overpass mirror $mirror failed: $error');
      }
    }
    throw const OverpassUnreachable();
  }

  static List<NearbyPlace> _placesFrom(Object? elements, LatLng centre) {
    if (elements is! List) return const [];
    final places = <NearbyPlace>[];
    for (final element in elements) {
      final place = NearbyPlace.fromOverpass(element, centre);
      if (place != null) places.add(place);
    }
    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return places.length <= nearbyResultLimit
        ? places
        : places.sublist(0, nearbyResultLimit);
  }

  /// Overpass QL. `out body 60` caps what the *server* sends; the list is then
  /// sorted by real distance here and cut to [nearbyResultLimit], because
  /// Overpass returns in its own order, not in distance order.
  static String _query(LatLng centre) {
    final at = '$nearbyRadiusMetres,${centre.latitude},${centre.longitude}';
    return '[out:json][timeout:25];'
        '('
        'node["amenity"="hospital"](around:$at);'
        'node["amenity"="clinic"](around:$at);'
        'node["amenity"="pharmacy"](around:$at);'
        ');'
        'out body 60;';
  }
}
