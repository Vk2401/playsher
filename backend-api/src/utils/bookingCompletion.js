const { Op } = require('sequelize');
const { appToday, isPastSlotEnd } = require('./appTime');

/**
 * Mark played bookings as `completed`.
 *
 * A booking is finished when its last slot has ended, but nothing was moving it
 * off `confirmed`, so a game from last month still read as upcoming and the
 * review gate (`review.controller.create` requires `completed`) could never
 * open.
 *
 * Outstanding balance is deliberately NOT a condition. Nothing in the API ever
 * zeroes `balance_due` — the venue takes that cash in person — so gating on it
 * does not mean "we cannot tell yet", it means "we can never tell", and every
 * pay-at-ground booking would stay upcoming forever. Whether the game was
 * played and whether the money was collected are separate facts; uncollected
 * cash is a report over `completed AND balance_due > 0`, not a reason to
 * pretend the match has not happened.
 *
 * Runs opportunistically on booking reads, the same way `releaseExpiredHolds`
 * does, so no cron is needed. The candidate set drains itself: once a row is
 * `completed` it never matches again, leaving only today's bookings to check.
 *
 * @param {object}  models                 { Booking }
 * @param {object}  [scope]
 * @param {number}  [scope.userId]         limit to one customer's bookings
 * @param {number}  [scope.bookingId]      limit to a single booking
 * @param {import('sequelize').Transaction} [transaction]
 * @returns {Promise<number>} how many bookings were completed
 */
async function completeFinishedBookings({ Booking }, scope = {}, transaction) {
  const where = {
    status     : 'confirmed',
    is_canceled: false,
    // Coarse filter in SQL; the exact end time is judged below, in the app
    // timezone, which the database column knows nothing about.
    slot_date  : { [Op.lte]: appToday() },
  };
  if (scope.userId) where.user_id = scope.userId;
  if (scope.bookingId) where.id = scope.bookingId;

  const opts = transaction ? { transaction } : {};
  const candidates = await Booking.findAll({
    where,
    attributes: ['id', 'slot_date', 'slot_time_from', 'slot_time_to'],
    ...opts,
  });

  const finished = candidates
    .filter((b) => isPastSlotEnd(b.slot_date, b.slot_time_from, b.slot_time_to))
    .map((b) => b.id);
  if (finished.length === 0) return 0;

  await Booking.update(
    { status: 'completed' },
    { where: { id: { [Op.in]: finished } }, ...opts },
  );

  return finished.length;
}

module.exports = { completeFinishedBookings };
