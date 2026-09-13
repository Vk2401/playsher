import 'package:flutter/foundation.dart';

import 'map_links.dart';
import 'phone_links.dart';

/// The two things a player needs on the way to a game: how to get there, and
/// who to ring when they cannot find the gate.
///
/// A value object rather than four loose parameters because it travels — the
/// detail screen hands it to checkout through GoRouter's `extra`, the same way
/// the venue name and image already ride along, so the checkout screen never
/// re-fetches a ground the previous screen had open.
@immutable
class VenueContact {
  /// The number exactly as the owner typed it. Displayed as-is; dialed only
  /// after [PhoneLinks.sanitize] has stripped the decoration.
  final String? phone;
  final double? latitude;
  final double? longitude;

  const VenueContact({this.phone, this.latitude, this.longitude});

  /// Null when the ground's coordinates are unset — see [MapLinks].
  String? get directionsUrl =>
      MapLinks.directionsUrl(latitude: latitude, longitude: longitude);

  /// Null when there is nothing a dialer could use — see [PhoneLinks].
  String? get callableNumber => PhoneLinks.sanitize(phone);

  /// What the number looks like on screen, keeping the owner's own spacing.
  String? get displayNumber => PhoneLinks.display(phone);

  bool get hasDirections => directionsUrl != null;
  bool get hasPhone => callableNumber != null;

  /// True when the venue offers neither, in which case callers render nothing
  /// rather than an empty row of disabled buttons.
  bool get isEmpty => !hasDirections && !hasPhone;

  @override
  bool operator ==(Object other) =>
      other is VenueContact &&
      other.phone == phone &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(phone, latitude, longitude);
}
