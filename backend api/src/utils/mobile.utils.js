/**
 * Indian mobile number helpers.
 *
 * Canonical wire format is `+91` followed by 10 digits starting 6-9 — the same
 * shape the Flutter app sends (see mobile_app/lib/screens/phone_screen.dart).
 * Accepts `9876543210`, `+919876543210`, `919876543210` and spaced/hyphenated
 * variants; everything is stored and looked up as `+919876543210`.
 */

const INDIAN_MOBILE = /^(?:\+?91)?([6-9]\d{9})$/;

/** Returns `+91XXXXXXXXXX`, or null when the input is not an Indian mobile. */
exports.normalizeIndianMobile = (raw) => {
  const match = String(raw ?? '').replace(/[\s-]/g, '').match(INDIAN_MOBILE);
  return match ? `+91${match[1]}` : null;
};
