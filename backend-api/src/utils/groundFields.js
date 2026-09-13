/**
 * Field whitelist for owner-submitted ground payloads.
 *
 * An owner may describe their ground; they may not moderate it. Spreading
 * req.body straight into Ground.create/update let an owner send
 * `is_approved: true` and self-approve past admin review — and since the public
 * ground list filters on `is_approved`, that published an unmoderated ground.
 * `owner_id` and `deleted_at` are likewise not the owner's to set.
 */
const OWNER_GROUND_FIELDS = [
  'name', 'about', 'description', 'latitude', 'longitude',
  'address', 'area', 'city', 'has_roof', 'price_per_slot',
  'venue_rules', 'contact_number', 'is_active',
];

/**
 * Coerce a multipart value to a boolean.
 * Multipart sends everything as a string, and the string 'false' is truthy in
 * JS — so a naive cast turns "closed for booking" into "open".
 */
/** Ground columns that are booleans on the model but arrive as form strings. */
const BOOLEAN_FIELDS = new Set(['is_active', 'has_roof']);

function asBool(value) {
  if (typeof value === 'boolean') return value;
  return !(value === 'false' || value === '0' || value === '');
}

/**
 * Normalise the venue's public phone number.
 * Clearing the field sends an empty string, and an empty string stored in the
 * column is not "no number" to any client — the app would render a Call button
 * that dials nothing. NULL is the only honest value for absent.
 */
function normaliseContact(value) {
  if (value === null || value === undefined) return null;
  const trimmed = String(value).trim();
  return trimmed === '' ? null : trimmed;
}

/** Pick only the fields an owner is allowed to set, coercing booleans. */
function pickGroundFields(body = {}) {
  const patch = {};
  for (const key of OWNER_GROUND_FIELDS) {
    if (body[key] === undefined) continue;
    // Multipart sends every field as a string, so "false" arrives truthy
    // unless each boolean is coerced by name.
    if (BOOLEAN_FIELDS.has(key))        patch[key] = asBool(body[key]);
    else if (key === 'contact_number')  patch[key] = normaliseContact(body[key]);
    else                                patch[key] = body[key];
  }
  return patch;
}

module.exports = { OWNER_GROUND_FIELDS, asBool, normaliseContact, pickGroundFields };
