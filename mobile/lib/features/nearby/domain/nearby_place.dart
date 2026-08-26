/// A hospital, clinic or pharmacy from OpenStreetMap.
///
/// Not a Ayuvo model — nothing in `server/` knows these exist. The web app
/// queries Overpass directly and so does this, which is why there is no
/// freezed/json_serializable pair here: the shape belongs to somebody else's
/// API and is decoded defensively rather than declared.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

enum PlaceKind {
  hospital,
  clinic,
  pharmacy;

  static PlaceKind from(String? amenity) => switch (amenity) {
        'hospital' => PlaceKind.hospital,
        'pharmacy' => PlaceKind.pharmacy,
        // Anything the query returned that is not one of the other two: the
        // Overpass filter only asks for these three, so an unexpected value is
        // far more likely to be a clinic variant than an error.
        _ => PlaceKind.clinic,
      };
}

@immutable
class NearbyPlace {
  const NearbyPlace({
    required this.id,
    required this.name,
    required this.kind,
    required this.position,
    required this.distanceKm,
  });

  final int id;
  final String name;
  final PlaceKind kind;
  final LatLng position;
  final double distanceKm;

  /// One decimal place. Overpass positions are node centroids, so a second
  /// decimal would be false precision about a building the size of a hospital.
  String get distanceLabel => distanceKm.toStringAsFixed(1);

  /// The OSM directions page. Opened in a browser, because Nepal has no
  /// reliable in-app routing and handing off to a real map app is better than
  /// drawing a line the user cannot follow.
  Uri get directions => Uri.parse(
        'https://www.openstreetmap.org/directions'
        '?to=${position.latitude},${position.longitude}',
      );

  /// Decodes one Overpass `element`, or null if it is not a mappable node.
  ///
  /// Ways and relations come back without `lat`/`lon` when `out body` is used
  /// (they carry a node list instead), so those are dropped rather than
  /// guessed at.
  static NearbyPlace? fromOverpass(Object? element, LatLng from) {
    if (element is! Map) return null;
    final lat = _asDouble(element['lat']);
    final lon = _asDouble(element['lon']);
    final id = element['id'];
    if (lat == null || lon == null || id is! int) return null;

    final tags = element['tags'];
    final amenity = tags is Map ? tags['amenity'] as String? : null;
    final kind = PlaceKind.from(amenity);
    final tagged = tags is Map ? tags['name'] as String? : null;
    final position = LatLng(lat, lon);

    return NearbyPlace(
      id: id,
      // An unnamed pharmacy is still worth showing — it is the one open at
      // 11pm — so the kind stands in for a name rather than the row vanishing.
      name: (tagged == null || tagged.trim().isEmpty)
          ? _titleCase(kind.name)
          : tagged.trim(),
      kind: kind,
      position: position,
      distanceKm: haversineKm(from, position),
    );
  }

  static double? _asDouble(Object? value) => switch (value) {
        final double v => v,
        final int v => v.toDouble(),
        _ => null,
      };

  static String _titleCase(String word) =>
      word[0].toUpperCase() + word.substring(1);
}

/// Great-circle distance in kilometres. Same formula the web app uses, so the
/// two apps agree on which pharmacy is nearest.
double haversineKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;
  final dLat = _radians(b.latitude - a.latitude);
  final dLon = _radians(b.longitude - a.longitude);
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.pow(math.sin(dLon / 2), 2) * math.cos(lat1) * math.cos(lat2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

double _radians(double degrees) => degrees * math.pi / 180;

/// Where the map opens when the device will not say where it is. The web app
/// uses the same point, and for this product's users it is a better guess than
/// the middle of the ocean.
const kathmandu = LatLng(27.7172, 85.324);

/// Matches the web app's Overpass query.
const nearbyRadiusMetres = 4000;

/// Overpass can return hundreds of nodes in a dense city. Forty markers is
/// already more than a phone screen can distinguish.
const nearbyResultLimit = 40;
