import 'package:url_launcher/url_launcher.dart';

/// Turning a ground's coordinates into directions.
///
/// Grounds carry latitude/longitude but nothing ever used them, so a booked
/// player had a venue name and no way to get there.
class MapLinks {
  const MapLinks._();

  /// A Google Maps directions URL for the venue.
  ///
  /// Uses the universal `https://www.google.com/maps/...` form rather than a
  /// `geo:` or `comgooglemaps:` scheme: it opens the Maps app when installed
  /// and the browser when not, on both platforms, and it stays a working link
  /// when pasted into a chat — which matters because this same URL goes into
  /// the shared booking text.
  ///
  /// Returns null when the ground has no usable coordinates, so callers hide
  /// the affordance rather than offering a button that goes nowhere.
  ///
  /// Coordinates only, no venue name: naming the pin needs a Maps place_id,
  /// which we do not store, and passing a name as the destination would make
  /// Maps search for it and risk landing on the wrong venue.
  static String? directionsUrl({double? latitude, double? longitude}) {
    if (!_usable(latitude) || !_usable(longitude)) return null;

    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    }).toString();
  }

  /// Opens the directions link. Returns false when there is nothing to open or
  /// no app could handle it, so the caller can say so instead of failing mute.
  static Future<bool> openDirections({
    double? latitude,
    double? longitude,
  }) async {
    final url = directionsUrl(latitude: latitude, longitude: longitude);
    if (url == null) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 0,0 is the null island — almost always an unset column rather than a real
  /// venue, and sending someone into the Atlantic is worse than no link.
  static bool _usable(double? value) =>
      value != null && value.isFinite && value != 0;
}
