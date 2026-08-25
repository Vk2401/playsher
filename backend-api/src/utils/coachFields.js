/**
 * Field whitelists for coach payloads.
 *
 * The same rule the ground owner is held to: a coach may describe and price
 * themselves, but may not moderate their own listing. Spreading req.body into
 * Coach.update would let a coach send `is_approved: true` and appear in the
 * public directory without ever passing admin review — and `password_hash`
 * straight through the body would be worse still.
 *
 * `email` is left out on purpose: it is the login identity, and changing it is
 * an admin action rather than a profile edit.
 */
const COACH_SELF_FIELDS = [
  'name', 'mobile', 'city', 'sport_id', 'sport_name', 'experience_years',
  'level', 'about', 'experience_details', 'awards', 'qualities',
  'latitude', 'longitude', 'availability', 'price_per_slot',
];

/** What an admin may set on any coach — the profile plus the moderation flags. */
const ADMIN_COACH_FIELDS = [
  ...COACH_SELF_FIELDS,
  'email', 'is_active', 'is_approved', 'rejection_reason',
];

/** Coach columns that are booleans on the model but arrive as form strings. */
const BOOLEAN_FIELDS = new Set(['is_active', 'is_approved']);

/** Columns that must be stored as a number, never as the string multipart sends. */
const NUMERIC_FIELDS = new Set([
  'price_per_slot', 'experience_years', 'sport_id', 'latitude', 'longitude',
]);

function asBool(value) {
  if (typeof value === 'boolean') return value;
  return !(value === 'false' || value === '0' || value === '');
}

function pick(body, allowed) {
  const patch = {};
  for (const key of allowed) {
    if (body[key] === undefined) continue;
    if (BOOLEAN_FIELDS.has(key)) {
      patch[key] = asBool(body[key]);
    } else if (NUMERIC_FIELDS.has(key)) {
      // '' from a cleared form field means "unset", not 0 — a coach who blanks
      // their experience should not be recorded as having none.
      patch[key] = body[key] === '' || body[key] === null ? null : Number(body[key]);
    } else {
      patch[key] = body[key];
    }
  }
  return patch;
}

/** Pick only the fields a coach may set on themselves. */
const pickCoachSelfFields = (body = {}) => pick(body, COACH_SELF_FIELDS);

/** Pick only the fields an admin may set on a coach. */
const pickAdminCoachFields = (body = {}) => pick(body, ADMIN_COACH_FIELDS);

module.exports = {
  COACH_SELF_FIELDS,
  ADMIN_COACH_FIELDS,
  pickCoachSelfFields,
  pickAdminCoachFields,
};
