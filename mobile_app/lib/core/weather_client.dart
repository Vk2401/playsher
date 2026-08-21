import 'package:dio/dio.dart';

import '../models/weather_model.dart';

/// Weather for a set of venue coordinates.
///
/// Deliberately NOT on ApiClient: that client attaches the Playsher bearer
/// token and owns the 401-refresh flow, neither of which should ever be
/// pointed at a third party. This is its own bare Dio with a short timeout.
///
/// Open-Meteo takes comma-separated coordinate lists, so a screenful of venues
/// costs one request rather than one per card.
class WeatherClient {
  const WeatherClient._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.open-meteo.com/v1',
    // Weather is decoration. If it is slow, the list must not be.
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  /// Open-Meteo caps how much it will answer at once, and a longer URL risks a
  /// 414. Screens show far fewer than this at a time.
  static const maxPoints = 50;

  /// Current conditions for each coordinate, in the order given.
  ///
  /// Returns an empty list on any failure — offline, rate limited, a changed
  /// payload. Callers render nothing rather than an error: a missing
  /// temperature is not worth telling anyone about.
  static Future<List<Weather>> forCoordinates(
    List<({double latitude, double longitude})> points,
  ) async {
    if (points.isEmpty) return const [];
    final capped = points.take(maxPoints).toList();

    try {
      final res = await _dio.get('/forecast', queryParameters: {
        'latitude': capped.map((p) => p.latitude).join(','),
        'longitude': capped.map((p) => p.longitude).join(','),
        'current': 'temperature_2m,weather_code,precipitation',
        'timezone': 'auto',
      });

      final data = res.data;
      // A single coordinate comes back as an object; several come back as a
      // list. Normalise so callers never have to care.
      final entries = data is List
          ? data.cast<Map<String, dynamic>>()
          : [data as Map<String, dynamic>];

      return entries.map(Weather.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }
}
