// Distance is the number a player scans a grounds list for, so a wrong one is
// worse than none. These pin the two ways it can go wrong: bad arithmetic, and
// a coordinate that is not really a coordinate.

import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/geo.dart';

// Chennai landmarks, and a venue in another city.
const _chennaiCentral = (lat: 13.0827, lng: 80.2707);
const _tNagar = (lat: 13.0418, lng: 80.2341);
const _bengaluru = (lat: 12.9716, lng: 77.5946);

double _km(({double lat, double lng}) from, ({double lat, double lng}) to) =>
    Geo.distanceKm(
      fromLat: from.lat,
      fromLng: from.lng,
      toLat: to.lat,
      toLng: to.lng,
    )!;

void main() {
  group('distanceKm', () {
    test('measures a short city hop', () {
      // Chennai Central to T. Nagar is about 6 km as the crow flies.
      expect(_km(_chennaiCentral, _tNagar), closeTo(6.1, 0.4));
    });

    test('measures a long inter-city hop', () {
      // Chennai to Bengaluru is about 290 km straight line.
      expect(_km(_chennaiCentral, _bengaluru), closeTo(290, 5));
    });

    test('is zero for the same point and symmetric between two', () {
      expect(_km(_tNagar, _tNagar), closeTo(0, 0.001));
      expect(_km(_chennaiCentral, _tNagar),
          closeTo(_km(_tNagar, _chennaiCentral), 0.001));
    });

    test('returns null when either end is missing or unusable', () {
      expect(
        Geo.distanceKm(fromLat: 13.08, fromLng: 80.27, toLat: null, toLng: 80.0),
        isNull,
      );
      // 0,0 is the null island: in this data an unset column, not a venue.
      expect(
        Geo.distanceKm(fromLat: 13.08, fromLng: 80.27, toLat: 0, toLng: 0),
        isNull,
      );
      expect(
        Geo.distanceKm(
            fromLat: 13.08, fromLng: 80.27, toLat: 91, toLng: 80.0),
        isNull,
      );
      expect(
        Geo.distanceKm(
            fromLat: double.nan, fromLng: 80.27, toLat: 13.0, toLng: 80.0),
        isNull,
      );
    });
  });

  group('format', () {
    test('reads sub-kilometre distances in metres', () {
      // "0.4 km" makes a five-minute walk look like a drive.
      expect(Geo.format(0.42), '420 m');
      expect(Geo.format(0.999), '999 m');
    });

    test('keeps one decimal under 10 km and drops it above', () {
      expect(Geo.format(1.0), '1.0 km');
      expect(Geo.format(2.44), '2.4 km');
      expect(Geo.format(9.96), '10.0 km');
      expect(Geo.format(12.4), '12 km');
      expect(Geo.format(289.6), '290 km');
    });
  });

  group('usable', () {
    test('accepts a real coordinate and rejects the ways one goes wrong', () {
      expect(Geo.usable(13.0827, 80.2707), isTrue);
      // The equator and the prime meridian are fine on their own; only the
      // pair 0,0 is treated as unset.
      expect(Geo.usable(0, 80.2707), isTrue);
      expect(Geo.usable(13.0827, 0), isTrue);
      expect(Geo.usable(0, 0), isFalse);
      expect(Geo.usable(null, 80.2707), isFalse);
      expect(Geo.usable(13.0827, 181), isFalse);
      expect(Geo.usable(double.infinity, 80.2707), isFalse);
    });
  });
}
