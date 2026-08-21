/// Current conditions at a venue.
///
/// From Open-Meteo, which needs no API key and no account — so nothing here
/// has to be configured before it works, and no credential can leak.
class Weather {
  final double temperatureC;

  /// WMO weather code. The vocabulary Open-Meteo reports conditions in.
  final int code;

  /// Millimetres in the last hour.
  final double precipitationMm;

  const Weather({
    required this.temperatureC,
    required this.code,
    this.precipitationMm = 0,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? json;
    return Weather(
      temperatureC:
          double.tryParse(current['temperature_2m']?.toString() ?? '') ?? 0,
      code: int.tryParse(current['weather_code']?.toString() ?? '') ?? 0,
      precipitationMm:
          double.tryParse(current['precipitation']?.toString() ?? '') ?? 0,
    );
  }

  String get temperatureLabel => '${temperatureC.round()}°C';

  /// True when an open-air game is a bad idea. Drives the warning on a venue
  /// with no roof — which is the whole reason the weather is here.
  bool get isWet => precipitationMm > 0 || _wetCodes.contains(code);

  /// A short human description of [code]. Grouped rather than exhaustive: a
  /// player needs "raining", not "moderate drizzle, freezing".
  String get description {
    if (code == 0) return 'Clear';
    if (code <= 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    // WMO codes stop at 99; an open-ended >= would label any stray number a
    // thunderstorm rather than admitting it is unrecognised.
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  static const _wetCodes = {
    51, 53, 55, 56, 57, // drizzle
    61, 63, 65, 66, 67, // rain
    80, 81, 82, // showers
    95, 96, 99, // thunderstorm
  };
}
