/**
 * Handles — the name a player is found by.
 *
 * A game is played with strangers, so a player needs an identity that can be
 * typed, shared and searched without handing out a phone number. That is what a
 * username is for here, and it carries three rules:
 *
 * 1. **Every account has one from the moment it exists.** A handle assigned
 *    later is a handle half the accounts do not have, and a search that misses
 *    half the users is worse than no search. Registration generates one; an
 *    account that predates this reads one on its first profile fetch.
 * 2. **It is unique, case-insensitively.** Stored lowercase, compared lowercase.
 *    `Ravi` and `ravi` are the same person to a human, so they must not be two
 *    accounts — impersonation is the whole risk a handle introduces.
 * 3. **The database is the arbiter, not the check.** `isAvailable` is what the
 *    signup form shows while typing; the unique index is what actually decides.
 *    Two people can pass the same check in the same second, so every write
 *    catches the constraint violation and says so.
 */
const { Op } = require('sequelize');

/** 3–30 characters: lowercase letters, digits and underscore. */
const PATTERN = /^[a-z0-9_]{3,30}$/;

/**
 * Names nobody may take.
 *
 * Two kinds: words that would let an account impersonate the platform or its
 * staff, and words that are — or could become — a path segment the clients
 * route on, since a handle ends up in a URL. Checked against the *normalised*
 * form, so `Admin` and `admin` are both refused.
 */
const RESERVED = new Set([
  'playsher', 'play', 'admin', 'administrator', 'root', 'support', 'help',
  'official', 'staff', 'team', 'moderator', 'mod', 'system', 'security',
  'owner', 'coach', 'user', 'users', 'player', 'players', 'me', 'self',
  'game', 'games', 'booking', 'bookings', 'ground', 'grounds', 'venue',
  'venues', 'search', 'settings', 'profile', 'notifications', 'payment',
  'payments', 'about', 'terms', 'privacy', 'contact', 'api', 'www', 'null',
  'undefined', 'anonymous', 'deleted',
]);

/** Words a generated handle is built from. Short, sporty, unambiguous. */
const ADJECTIVES = [
  'swift', 'bold', 'sharp', 'clutch', 'solid', 'quick', 'lively', 'steady',
  'keen', 'brave', 'nimble', 'sunny', 'lucky', 'wild', 'calm', 'smart',
];
const NOUNS = [
  'striker', 'keeper', 'winger', 'sprinter', 'spinner', 'smasher', 'ace',
  'rally', 'volley', 'dribble', 'baseline', 'skipper', 'allrounder', 'sweeper',
  'playmaker', 'opener',
];

/**
 * Fold anything a person might type into the stored form.
 *
 * Trims, lowercases, and drops a leading `@` — people type the handle the way
 * they read it, and refusing `@ravi` because of a character the UI itself
 * renders would be a puzzle rather than a rule.
 */
function normalise(raw) {
  return String(raw ?? '').trim().replace(/^@+/, '').toLowerCase();
}

/**
 * Why this handle cannot be used, or null when it can.
 *
 * Returns the sentence shown under the field, so the reason a name was refused
 * is the reason the person reads — never a generic "invalid username".
 */
function validationError(raw) {
  const value = normalise(raw);

  if (!value) return 'Pick a username.';
  if (value.length < 3) return 'A username needs at least 3 characters.';
  if (value.length > 30) return 'A username can be at most 30 characters.';
  if (!PATTERN.test(value)) {
    return 'Use lowercase letters, numbers and underscores only.';
  }
  // An all-digit handle would be indistinguishable from a user id in a path,
  // and `GET /players/:handle` resolves a numeric handle as an id.
  if (!/[a-z]/.test(value)) return 'A username must contain at least one letter.';
  if (value.startsWith('_') || value.endsWith('_')) {
    return 'A username cannot start or end with an underscore.';
  }
  if (value.includes('__')) return 'Use single underscores only.';
  if (RESERVED.has(value)) return 'That username is reserved.';

  return null;
}

/** A candidate handle. Not checked for collisions — that is the caller's job. */
function randomUsername() {
  const pick = (list) => list[Math.floor(Math.random() * list.length)];
  // Four digits keeps the pool wide enough that a first attempt almost always
  // lands, without producing a handle nobody would want to keep.
  const digits = String(Math.floor(Math.random() * 10000)).padStart(4, '0');
  return `${pick(ADJECTIVES)}_${pick(NOUNS)}${digits}`;
}

/**
 * A handle nothing else is using, ready to write.
 *
 * Tries random names, then falls back to something that cannot collide. The
 * fallback exists because a loop that can fail is a registration that can fail:
 * an account with no handle is worse than an ugly one, and the person can
 * change it.
 *
 * Still racy by nature — two calls can pick the same free name before either
 * writes. The unique index is the real guard; callers catch it.
 *
 * @param {import('sequelize').ModelStatic<any>} User
 * @param {import('sequelize').Transaction} [transaction]
 */
async function generateUniqueUsername(User, transaction) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const candidate = randomUsername();
    // eslint-disable-next-line no-await-in-loop
    const taken = await isTaken(User, candidate, null, transaction);
    if (!taken) return candidate;
  }

  // Deterministic tail: the epoch plus randomness, so even a pathological run
  // of collisions terminates rather than leaving the account unnamed.
  const tail = `${Date.now().toString(36)}${Math.floor(Math.random() * 1296).toString(36)}`;
  return `player_${tail}`.slice(0, 30);
}

/**
 * Is this handle already somebody's?
 *
 * Soft-deleted accounts still hold their handle: releasing it would let the
 * next person take over the name a shared game still credits to someone else.
 *
 * @param {number} [exceptUserId] the account asking, so re-saving your own
 *   handle is not reported as a clash with yourself.
 */
async function isTaken(User, raw, exceptUserId = null, transaction = undefined) {
  const value = normalise(raw);
  if (!value) return false;

  const where = { username: value };
  if (exceptUserId) where.id = { [Op.ne]: exceptUserId };

  const found = await User.findOne({
    where,
    attributes: ['id'],
    ...(transaction ? { transaction } : {}),
  });
  return Boolean(found);
}

/**
 * Does this error come from the username unique index — and not another one?
 *
 * The distinction matters: a caller catches this to retry with a fresh handle,
 * and retrying a *mobile* clash that way would spin, fail again, and bury the
 * real reason the account could not be created.
 *
 * Sequelize reports the offending column three different ways depending on the
 * driver — `errors[].path` is the consistent one, `fields` is an array on some
 * dialects and an object on others, and the driver message is the last resort.
 * All three are checked because getting this wrong is silent: it degrades into
 * "registration failed" with no clue why.
 */
function isUsernameConflict(err) {
  if (err?.name !== 'SequelizeUniqueConstraintError') return false;

  const paths = (err.errors || []).map((e) => e?.path).filter(Boolean);
  if (paths.length) return paths.includes('username');

  const fields = err.fields;
  if (Array.isArray(fields)) return fields.includes('username');
  if (fields && typeof fields === 'object') {
    return Object.keys(fields).some((f) => String(f).toLowerCase().includes('username'));
  }

  const message = String(err.original?.message ?? err.parent?.message ?? err.message ?? '');
  return /username/i.test(message);
}

module.exports = {
  PATTERN,
  RESERVED,
  normalise,
  validationError,
  randomUsername,
  generateUniqueUsername,
  isTaken,
  isUsernameConflict,
};
