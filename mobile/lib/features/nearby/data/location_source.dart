/// Where the phone thinks it is — behind an interface, so the map screen can
/// be tested without a GPS.
///
/// Location is the one permission in this app that a user can reasonably say no
/// to and still get value: the map falls back to Kathmandu and works. That is
/// why [LocationFix] carries *why* it is where it is, rather than just a point.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../domain/nearby_place.dart';

enum LocationOrigin {
  /// The device gave a real fix.
  device,

  /// The user refused, or has refused before.
  denied,

  /// Location services are off, or the platform has none.
  unavailable,
}

@immutable
class LocationFix {
  const LocationFix(this.position, this.origin);

  const LocationFix.fallback(this.origin) : position = kathmandu;

  final LatLng position;
  final LocationOrigin origin;

  bool get isReal => origin == LocationOrigin.device;
}

abstract interface class LocationSource {
  /// Never throws and never returns null: a map with no fix still has to open
  /// somewhere, and "we could not find you" is a state to render, not an error
  /// to handle.
  Future<LocationFix> current();
}

class DeviceLocation implements LocationSource {
  const DeviceLocation();

  @override
  Future<LocationFix> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFix.fallback(LocationOrigin.unavailable);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationFix.fallback(LocationOrigin.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // A pharmacy 4 km away does not need metre accuracy, and asking for
          // it costs battery and a much longer first fix indoors.
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationFix(
        LatLng(position.latitude, position.longitude),
        LocationOrigin.device,
      );
    } catch (error) {
      // Timeouts, a platform with no location plugin, an OEM that throws on a
      // cold GPS. All of them mean the same thing to this screen.
      debugPrint('Location unavailable: $error');
      return const LocationFix.fallback(LocationOrigin.unavailable);
    }
  }
}

/// For tests and for a desktop run.
class FixedLocation implements LocationSource {
  const FixedLocation(this.fix);

  final LocationFix fix;

  @override
  Future<LocationFix> current() async => fix;
}

final locationSourceProvider = Provider<LocationSource>((ref) {
  if (kIsWeb) return const FixedLocation(LocationFix.fallback(LocationOrigin.unavailable));
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => const DeviceLocation(),
    _ => const FixedLocation(LocationFix.fallback(LocationOrigin.unavailable)),
  };
});
