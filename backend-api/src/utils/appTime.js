/**
 * Wall-clock time in the timezone the *product* runs in.
 *
 * The API is deployed on hosts that run UTC (Vercel always does, and Sequelize
 * is pinned to '+00:00'), but slot times are stored as local wall-clock strings
 * — a ground that opens at 06:00 means 06:00 IST, not 06:00 UTC. Comparing a
 * stored '14:00:00' against `new Date().getHours()` therefore compared IST
 * against UTC and ran 5h30m behind: at 14:51 IST the server believed it was
 * 09:21, so every already-played slot from 10:00 onward was still offered.
 *
 * Anything that compares a stored slot_date / slot_start_time against "now"
 * must go through here. Absolute instants (created_at, hold_expires_at, token
 * expiry) are correct as UTC Date objects and must NOT use these helpers.
 */

// Single-city product today, but the zone is the one thing that changes if
// Playsher ever launches outside India — so it reads from the environment.
const APP_TIMEZONE = process.env.APP_TIMEZONE || 'Asia/Kolkata';

const partsFormatter = new Intl.DateTimeFormat('en-US', {
  timeZone : APP_TIMEZONE,
  hour12   : false,
  year     : 'numeric',
  month    : '2-digit',
  day      : '2-digit',
  hour     : '2-digit',
  minute   : '2-digit',
});

/**
 * The current wall-clock date and time in the app timezone.
 * @param {Date} [at] instant to read, defaults to now
 * @returns {{ date: string, minutes: number }} `date` is YYYY-MM-DD,
 *   `minutes` is minutes elapsed since midnight that day.
 */
function appNow(at = new Date()) {
  const parts = {};
  for (const { type, value } of partsFormatter.formatToParts(at)) {
    parts[type] = value;
  }
  // 'hour: 2-digit' with hour12:false emits '24' for midnight in some ICU
  // builds; normalise so midnight is 0 minutes, not 1440.
  const hour = Number(parts.hour) % 24;
  return {
    date   : `${parts.year}-${parts.month}-${parts.day}`,
    minutes: hour * 60 + Number(parts.minute),
  };
}

/** Today's calendar date in the app timezone, as YYYY-MM-DD. */
function appToday(at = new Date()) {
  return appNow(at).date;
}

/** Minutes since midnight of a 'HH:MM[:SS]' wall-clock string. */
function timeToMinutes(time) {
  const [h, m] = String(time).split(':').map(Number);
  if (Number.isNaN(h) || Number.isNaN(m)) return NaN;
  return h * 60 + m;
}

/**
 * Has this slot's start time already passed in the app timezone?
 * Unparseable times are treated as *not* past, so a malformed row is shown
 * rather than silently swallowed.
 */
function isPastSlot(slotDate, startTime, at = new Date()) {
  const now = appNow(at);
  if (slotDate < now.date) return true;
  if (slotDate > now.date) return false;
  const minutes = timeToMinutes(startTime);
  if (Number.isNaN(minutes)) return false;
  return minutes <= now.minutes;
}

/**
 * Day of week for a YYYY-MM-DD string, 0=Sun … 6=Sat.
 * Anchored to UTC midnight so the result depends only on the date string —
 * `new Date('2026-08-20T00:00:00')` parses in *server* local time and lands on
 * the previous day on any host west of UTC.
 */
function dayOfWeek(dateString) {
  return new Date(`${dateString}T00:00:00Z`).getUTCDay();
}

module.exports = { APP_TIMEZONE, appNow, appToday, timeToMinutes, isPastSlot, dayOfWeek };
