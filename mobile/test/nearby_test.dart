/// Nearby care: decoding somebody else's API defensively, and surviving the
/// fact that Overpass is a free service that is often busy.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ayuvo/features/nearby/data/overpass_repository.dart';
import 'package:ayuvo/features/nearby/domain/nearby_place.dart';

import 'support/fake_http.dart';

const _here = LatLng(27.7172, 85.324);

Map<String, Object?> node({
  int id = 1,
  double lat = 27.72,
  double lon = 85.33,
  String? amenity = 'hospital',
  String? name = 'Bir Hospital',
}) =>
    {
      'id': id,
      'lat': lat,
      'lon': lon,
      'tags': {'amenity': ?amenity, 'name': ?name},
    };

OverpassRepository repositoryOn(FakeAdapter adapter) =>
    OverpassRepository(Dio()..httpClientAdapter = adapter);

void main() {
  group('distance', () {
    test('the same point is zero away', () {
      expect(haversineKm(_here, _here), closeTo(0, 0.0001));
    });

    test('a kilometre north measures about a kilometre', () {
      // 0.009° of latitude is roughly 1 km anywhere on Earth.
      const north = LatLng(27.7262, 85.324);
      expect(haversineKm(_here, north), closeTo(1.0, 0.05));
    });
  });

  group('decoding an element', () {
    test('a tagged node becomes a place with its distance', () {
      final place = NearbyPlace.fromOverpass(node(), _here)!;

      expect(place.name, 'Bir Hospital');
      expect(place.kind, PlaceKind.hospital);
      expect(place.distanceKm, greaterThan(0));
    });

    test('an unnamed pharmacy is still worth showing', () {
      // It is the one open at eleven at night.
      final place = NearbyPlace.fromOverpass(
        node(amenity: 'pharmacy', name: null),
        _here,
      )!;

      expect(place.name, 'Pharmacy');
      expect(place.kind, PlaceKind.pharmacy);
    });

    test('a way with no coordinates is dropped rather than guessed at', () {
      final element = {'id': 2, 'tags': {'amenity': 'clinic'}};

      expect(NearbyPlace.fromOverpass(element, _here), isNull);
    });

    test('an integer coordinate is still a coordinate', () {
      // Overpass sends JSON numbers; a whole one decodes as int in Dart.
      final place = NearbyPlace.fromOverpass(
        {'id': 3, 'lat': 27, 'lon': 85, 'tags': const {'amenity': 'clinic'}},
        _here,
      );

      expect(place, isNotNull);
    });

    test('an unexpected amenity falls back to clinic, not to nothing', () {
      final place = NearbyPlace.fromOverpass(
        node(amenity: 'doctors'),
        _here,
      )!;

      expect(place.kind, PlaceKind.clinic);
    });

    test('rubbish is null, not an exception', () {
      expect(NearbyPlace.fromOverpass('not a node', _here), isNull);
      expect(NearbyPlace.fromOverpass(null, _here), isNull);
    });
  });

  group('the query', () {
    test('results come back nearest first', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'elements': [
            node(id: 1, lat: 27.80, lon: 85.40, name: 'Far'),
            node(id: 2, lat: 27.7175, lon: 85.3245, name: 'Near'),
          ],
        }),
      );

      final places = await repositoryOn(adapter).around(_here);

      expect(places.map((p) => p.name), ['Near', 'Far']);
    });

    test('a busy mirror is skipped and the next one answers', () async {
      // 429 and 504 are ordinary operation for a donated public service.
      var call = 0;
      final adapter = FakeAdapter((_) {
        call++;
        return call == 1
            ? jsonResponse({'error': 'rate limited'}, statusCode: 429)
            : jsonResponse({'elements': [node()]});
      });

      final places = await repositoryOn(adapter).around(_here);

      expect(places, hasLength(1));
      expect(call, 2);
    });

    test('a mirror that throws is skipped too', () async {
      var call = 0;
      final adapter = FakeAdapter((_) {
        call++;
        if (call < 3) throw const SocketExceptionStub();
        return jsonResponse({'elements': [node()]});
      });

      final places = await repositoryOn(adapter).around(_here);

      expect(places, hasLength(1));
      expect(call, 3);
    });

    test('every mirror refusing is a named failure, not a generic one',
        () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({'error': 'busy'}, statusCode: 504),
      );

      await expectLater(
        repositoryOn(adapter).around(_here),
        throwsA(isA<OverpassUnreachable>()),
      );
    });

    test('all three mirrors are tried before giving up', () async {
      var call = 0;
      final adapter = FakeAdapter((_) {
        call++;
        return jsonResponse({'error': 'busy'}, statusCode: 504);
      });

      await repositoryOn(adapter).around(_here).catchError(
            (_) => <NearbyPlace>[],
          );

      expect(call, overpassMirrors.length);
    });

    test('a dense city is capped at what a phone can distinguish', () async {
      final adapter = FakeAdapter(
        (_) => jsonResponse({
          'elements': [
            for (var i = 0; i < 60; i++)
              node(id: i, lat: 27.72 + i * 0.0001, lon: 85.33),
          ],
        }),
      );

      final places = await repositoryOn(adapter).around(_here);

      expect(places, hasLength(nearbyResultLimit));
    });

    test('the request carries a form-encoded Overpass query', () async {
      final adapter = FakeAdapter((_) => jsonResponse({'elements': []}));

      await repositoryOn(adapter).around(_here);

      final request = adapter.requests.single;
      expect(request.options.uri.toString(), overpassMirrors.first);
      expect(request.body, startsWith('data='));
      expect(Uri.decodeQueryComponent(request.body.substring(5)),
          contains('amenity"="pharmacy'));
    });
  });
}

/// A stand-in for a connection failure. `FakeAdapter` turns anything thrown
/// from `respond` into a failed request, so the type only has to be throwable.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
