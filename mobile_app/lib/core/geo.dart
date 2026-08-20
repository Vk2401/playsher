import 'dart:math' as math;

/// Great-circle distance between the user and a venue.
///
/// Pure Dart on purpose: the plugin layer (`geolocator`) belongs to the
/// location provider, and widgets that only need "how far is this" should not
/// pull a platform channel in to ask.
class Geo {
  const Geo._();

  static const double _earthRadiusKm = 6371.0088;

  /// Kilometres between two coordinates, or `null` when either pair is
  /// unusable — see [usable].
  static double? distanceKm({
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
  }) {
    if (!usable(fromLat, fromLng) || !usable(toLat, toLng)) return null;

    final lat1 = _rad(fromLat!);
    final lat2 = _rad(toLat!);
    final dLat = lat2 - lat1;
    final dLng = _rad(toLng!) - _rad(fromLng!);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);

    return _earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// A short label for a distance: `450 m`, `2.4 km`, `18 km`.
  ///
  /// Sub-kilometre reads in metres because "0.4 km" makes a five-minute walk
  /// look like a drive; past 10 km the decimal is noise.
  static String format(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// Whether a coordinate pair points at a real place.
  ///
  /// Rejects nulls, non-finite values, out-of-range degrees, and 0,0 — the
  /// null island, which in this data is an unset column rather than a venue.
  static bool usable(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    return !(lat == 0 && lng == 0);
  }

  static double _rad(double degrees) => degrees * math.pi / 180.0;
}
