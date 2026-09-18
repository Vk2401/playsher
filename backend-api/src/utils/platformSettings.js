/**
 * Reading and writing operator-tunable settings.
 *
 * Cached in memory for a short window because the commission rate is read on
 * every settled payment and changes perhaps twice a year — but the cache is
 * cleared on write, so a super admin who changes the rate sees it take effect
 * immediately rather than up to a minute later on whichever process served
 * them. Other processes pick it up when their own window lapses.
 *
 * Every getter falls back rather than throwing. A settings table that is
 * unreachable, or a row someone typed nonsense into, must not stop payments
 * being settled — it falls back to the environment, then to the built-in
 * default, and says so in the log.
 */
const { PlatformSetting } = require('../models');
const { DEFAULT_COMMISSION_RATE } = require('./commission');

const COMMISSION_KEY = 'platform_commission_rate';
const CACHE_MS = 60_000;

const cache = new Map();

function cached(key) {
  const hit = cache.get(key);
  if (!hit || Date.now() > hit.expires) return undefined;
  return hit.value;
}

function remember(key, value) {
  cache.set(key, { value, expires: Date.now() + CACHE_MS });
}

/** Drop the cache so the next read hits the table. Called on every write. */
function invalidate(key) {
  if (key) cache.delete(key);
  else cache.clear();
}

/** Raw string value, or undefined when unset/unreadable. */
async function getRaw(key) {
  const hit = cached(key);
  if (hit !== undefined) return hit;

  try {
    const row = await PlatformSetting.findOne({ where: { setting_key: key } });
    const value = row ? row.value : null;
    remember(key, value);
    return value;
  } catch (err) {
    // Table missing (schema not applied yet) or database down. Neither is a
    // reason to fail the caller; they have their own fallback.
    console.warn('[settings] could not read %s: %s', key, err.message);
    return null;
  }
}

/**
 * The commission rate in force right now.
 *
 * Order: the settings table, then PLATFORM_COMMISSION_RATE, then the built-in
 * default. A stored value outside [0, 1) is ignored rather than applied — the
 * table is editable by a human, and a typo there must not hand away every
 * booking or charge the whole of one.
 *
 * @returns {Promise<number>}
 */
async function getCommissionRate() {
  const stored = await getRaw(COMMISSION_KEY);

  if (stored !== null && stored !== undefined && String(stored).trim() !== '') {
    const rate = Number(stored);
    if (Number.isFinite(rate) && rate >= 0 && rate < 1) return rate;
    console.warn('[settings] stored commission rate %j is out of range; ignoring', stored);
  }

  // Same guards as commission.commissionRate(), kept in that module so the
  // pure split stays usable without a database.
  const { commissionRate } = require('./commission');
  return commissionRate();
}

/**
 * Set the commission rate. Validates before writing, so the table can only ever
 * hold a usable value and readers do not have to defend against the impossible.
 *
 * @param {number|string} rate     fraction, 0 to just under 1
 * @param {number} [adminId]       who changed it
 * @returns {Promise<{ ok:boolean, rate?:number, reason?:string }>}
 */
async function setCommissionRate(rate, adminId = null) {
  const value = Number(rate);
  if (!Number.isFinite(value) || value < 0 || value >= 1) {
    return { ok: false, reason: 'Commission must be a number from 0 up to (but not including) 1.' };
  }

  // Four decimals is 0.01% of resolution, well past anything a commercial
  // agreement uses, and keeps the stored text short and comparable.
  const normalised = Math.round(value * 10000) / 10000;

  await PlatformSetting.upsert({
    setting_key: COMMISSION_KEY,
    value: String(normalised),
    updated_by: adminId,
  });
  invalidate(COMMISSION_KEY);

  return { ok: true, rate: normalised };
}

/** Where the rate in force actually came from — shown in the admin UI. */
async function commissionSource() {
  const stored = await getRaw(COMMISSION_KEY);
  if (stored !== null && stored !== undefined && String(stored).trim() !== '') {
    const rate = Number(stored);
    if (Number.isFinite(rate) && rate >= 0 && rate < 1) return 'database';
  }
  const env = process.env.PLATFORM_COMMISSION_RATE;
  if (env !== undefined && String(env).trim() !== '') return 'environment';
  return 'default';
}

module.exports = {
  getCommissionRate,
  setCommissionRate,
  commissionSource,
  invalidate,
  COMMISSION_KEY,
  DEFAULT_COMMISSION_RATE,
};
