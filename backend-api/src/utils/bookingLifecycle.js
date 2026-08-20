const { Op } = require('sequelize');
const { appNow } = require('./appTime');

/**
 * Move confirmed bookings whose slot has finished to `completed`.
 *
 * Nothing in the API ever made this transition — there is no cron and no
 * scheduler — so every booking stayed `confirmed` forever. Two visible
 * consequences:
 *
 *   1. The app's "Past" tab was permanently empty and yesterday's match still
 *      showed as upcoming.
 *   2. Reviews were impossible. review.controller requires a `completed`
 *      booking, and no booking could ever reach that state.
 *
 * Runs opportunistically before a booking read, the way releaseExpiredHolds
 * does, so the status is right on the next request rather than needing a cron.
 *
 * `pending` is deliberately left alone: an unpaid booking that never got paid
 * is not a game that was played, and slot holds already handle it.
 *
 * @param {object} models              { Booking }
 * @param {object} [scope]
 * @param {number} [scope.userId]      limit the sweep to one customer
 * @param {import('sequelize').Transaction} [transaction]
 * @returns {Promise<number>} how many bookings were completed
 */
async function completePastBookings({ Booking }, scope = {}, transaction) {
  const now = appNow();

  const where = {
    status: 'confirmed',
    [Op.or]: [
      // Any earlier date is finished regardless of the time on it.
      { slot_date: { [Op.lt]: now.date } },
      // Today, but the booked window has already ended. Compared as a string
      // because slot_time_to is a wall-clock 'HH:MM:SS' in the venue's zone —
      // zero-padded, so lexical order matches chronological order.
      {
        slot_date: now.date,
        slot_time_to: { [Op.ne]: null, [Op.lt]: minutesToTime(now.minutes) },
      },
    ],
  };
  if (scope.userId) where.user_id = scope.userId;

  const opts = transaction ? { transaction } : {};
  const [count] = await Booking.update({ status: 'completed' }, { where, ...opts });
  return count;
}

/** 930 -> '15:30:00', the shape slot_time_to is stored in. */
function minutesToTime(minutes) {
  const h = String(Math.floor(minutes / 60)).padStart(2, '0');
  const m = String(minutes % 60).padStart(2, '0');
  return `${h}:${m}:00`;
}

module.exports = { completePastBookings, minutesToTime };
