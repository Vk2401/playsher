import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/weather_model.dart';

void main() {
  group('Weather parses the Open-Meteo shape', () {
    test('reads the current block', () {
      final w = Weather.fromJson({
        'current': {
          'temperature_2m': 31.4,
          'weather_code': 61,
          'precipitation': 0.6,
        }
      });
      expect(w.temperatureC, 31.4);
      expect(w.code, 61);
      expect(w.precipitationMm, 0.6);
    });

    test('numbers arriving as strings still parse', () {
      final w = Weather.fromJson({
        'current': {'temperature_2m': '28', 'weather_code': '0'}
      });
      expect(w.temperatureC, 28);
      expect(w.code, 0);
    });

    test('a missing payload degrades rather than throwing', () {
      final w = Weather.fromJson({});
      expect(w.temperatureC, 0);
      expect(w.code, 0);
      expect(w.isWet, isFalse);
    });

    test('rounds the temperature for display', () {
      expect(
        Weather.fromJson({'current': {'temperature_2m': 30.6}}).temperatureLabel,
        '31°C',
      );
    });
  });

  group('isWet — the thing an uncovered venue cares about', () {
    test('clear is dry', () {
      expect(const Weather(temperatureC: 30, code: 0).isWet, isFalse);
    });

    test('overcast is still dry', () {
      expect(const Weather(temperatureC: 30, code: 3).isWet, isFalse);
    });

    for (final code in [51, 61, 65, 80, 82, 95, 99]) {
      test('code $code counts as wet', () {
        expect(Weather(temperatureC: 28, code: code).isWet, isTrue);
      });
    }

    test('measured precipitation counts even on a dry-looking code', () {
      expect(
        const Weather(temperatureC: 28, code: 3, precipitationMm: 0.2).isWet,
        isTrue,
      );
    });
  });

  group('descriptions are grouped, not exhaustive', () {
    final cases = {
      0: 'Clear',
      2: 'Partly cloudy',
      3: 'Overcast',
      45: 'Fog',
      53: 'Drizzle',
      63: 'Rain',
      73: 'Snow',
      81: 'Showers',
      96: 'Thunderstorm',
    };
    cases.forEach((code, expected) {
      test('$code reads as "$expected"', () {
        expect(Weather(temperatureC: 20, code: code).description, expected);
      });
    });

    test('an unrecognised code is admitted, not guessed at', () {
      expect(const Weather(temperatureC: 20, code: 999).description, 'Unknown');
    });
  });
}
