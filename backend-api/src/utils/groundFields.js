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
  'address', 'venue_rules', 'contact_number', 'is_active',
];

/**
 * Coerce a multipart value to a boolean.
 * Multipart sends everything as a string, and the string 'false' is truthy in
 * JS — so a naive cast turns "closed for booking" into "open".
 */
function asBool(value) {
  if (typeof value === 'boolean') return value;
  return !(value === 'false' || value === '0' || value === '');
}

/** Pick only the fields an owner is allowed to set, coercing booleans. */
function pickGroundFields(body = {}) {
  const patch = {};
  for (const key of OWNER_GROUND_FIELDS) {
    if (body[key] === undefined) continue;
    patch[key] = key === 'is_active' ? asBool(body[key]) : body[key];
  }
  return patch;
}

module.exports = { OWNER_GROUND_FIELDS, asBool, pickGroundFields };
