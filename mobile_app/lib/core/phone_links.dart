import 'package:url_launcher/url_launcher.dart';

/// Turning a venue's published phone number into a call.
///
/// `grounds.contact_number` is free text an owner typed — "044 4567 8900",
/// "+91 98400 12345", sometimes a stray dash or a row left over from before the
/// column existed. The dialer wants none of that decoration, so everything here
/// goes through [sanitize] first.
class PhoneLinks {
  const PhoneLinks._();

  /// The number reduced to what a `tel:` URI may carry — a leading `+` and
  /// digits — or null when what is left could not be a phone number.
  ///
  /// Returns null rather than an empty string so callers hide the Call button
  /// instead of offering one that opens an empty dialer. Six digits is the
  /// floor: shorter than the shortest Indian landline, so anything under it is
  /// a typo or a placeholder, not a number worth showing.
  static String? sanitize(String? raw) {
    if (raw == null) return null;

    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final plus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return null;

    return plus ? '+$digits' : digits;
  }

  /// How the number is shown on screen: the owner's own spacing, kept, because
  /// "044 4567 8900" reads as a Chennai landline and "04445678900" does not.
  /// Falls back to the sanitized digits when the raw text is unusable.
  static String? display(String? raw) {
    final callable = sanitize(raw);
    if (callable == null) return null;

    final trimmed = raw!.trim();
    return trimmed.isEmpty ? callable : trimmed;
  }

  /// A `tel:` URI for the number, or null when there is nothing to dial.
  static Uri? dialUri(String? raw) {
    final number = sanitize(raw);
    return number == null ? null : Uri(scheme: 'tel', path: number);
  }

  /// Opens the dialer with the number filled in. Returns false when there is
  /// nothing to dial or no app could handle it, so the caller can say so
  /// instead of failing mute — the same contract as MapLinks.openDirections.
  ///
  /// `externalApplication` on purpose: the dialer *is* another app, and the
  /// platform default would try an in-app web view for the scheme first.
  static Future<bool> call(String? raw) async {
    final uri = dialUri(raw);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
