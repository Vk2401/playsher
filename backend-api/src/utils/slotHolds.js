const { Op } = require('sequelize');

/** How long an unpaid online booking may hold its slots. */
const HOLD_MINUTES = 5;

/**
 * Release slots held by online bookings whose payment window has lapsed.
 *
 * Booking marks its slots unavailable inside the transaction, but an online
 * booking stays `pending` until Razorpay confirms. Without this sweep a user who
 * opened the checkout and walked away blocked those slots forever.
 *
 * Runs opportunistically before any availability read or write, so an abandoned
 * hold frees up on the next request rather than needing a cron. Scoped to one
 * ground_sport + date where the caller knows them, so the common path touches a
 * handful of rows.
 *
 * @param {object}  models                  { Booking, BookedSlot, Slot }
 * @param {object}  [scope]
 * @param {number}  [scope.groundSportId]   limit the sweep to one ground sport
 * @param {string}  [scope.slotDate]        limit the sweep to one date
 * @param {import('sequelize').Transaction} [transaction]
 * @returns {Promise<number>} how many bookings were expired
 */
async function releaseExpiredHolds({ Booking, BookedSlot, Slot }, scope = {}, transaction) {
  const where = {
    status: 'pending',
    hold_expires_at: { [Op.ne]: null, [Op.lt]: new Date() },
  };
  if (scope.groundSportId) where.ground_sport_id = scope.groundSportId;
  if (scope.slotDate) where.slot_date = scope.slotDate;

  const opts = transaction ? { transaction } : {};
  const expired = await Booking.findAll({ where, ...opts });
  if (expired.length === 0) return 0;

  const bookingIds = expired.map((b) => b.id);

  const held = await BookedSlot.findAll({
    where: { booking_id: { [Op.in]: bookingIds } },
    ...opts,
  });
  const slotIds = held.map((h) => h.slot_id);

  if (slotIds.length > 0) {
    await Slot.update({ is_available: true }, { where: { id: { [Op.in]: slotIds } }, ...opts });
  }

  // Marked cancelled rather than deleted: the attempt is real history, and a
  // late payment callback must find the row to reconcile against.
  await Booking.update(
    {
      status: 'cancelled',
      is_canceled: true,
      cancellation_reason: 'Payment not completed in time',
      hold_expires_at: null,
    },
    { where: { id: { [Op.in]: bookingIds } }, ...opts },
  );

  return bookingIds.length;
}

/** Deadline for a hold starting now. */
function holdDeadline(from = new Date()) {
  return new Date(from.getTime() + HOLD_MINUTES * 60 * 1000);
}

module.exports = { releaseExpiredHolds, holdDeadline, HOLD_MINUTES };
