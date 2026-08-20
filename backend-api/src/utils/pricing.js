/**
 * Booking money, computed in one place.
 *
 * Every amount the client sees comes from here and is stored on the booking, so
 * the checkout screen, the ticket, the owner's list and any later reconciliation
 * all quote the same figures — rather than each recomputing a percentage that
 * may have changed in between.
 */

/** Share of the total taken online when paying at the ground. */
const ADVANCE_RATE = 0.10;

/** Floor for that advance, so a cheap slot still books against something real. */
const MIN_ADVANCE = 10;

/** Round to whole rupees; payment gateways deal badly with stray paise. */
function toRupees(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

/**
 * Split a booking total into what is taken now and what is owed later.
 *
 * @param {number} total          booking total
 * @param {string} paymentMethod  'online' | 'pay_at_ground'
 * @returns {{ total: number, advance: number, balance: number, requiresPayment: boolean }}
 */
function splitPayment(total, paymentMethod) {
  const amount = toRupees(total);

  if (paymentMethod === 'online') {
    return { total: amount, advance: amount, balance: 0, requiresPayment: amount > 0 };
  }

  // Pay at ground: take a deposit now, collect the rest at the venue. Never
  // charge an advance larger than the booking itself.
  const advance = amount <= 0
    ? 0
    : Math.min(amount, Math.max(MIN_ADVANCE, Math.ceil(amount * ADVANCE_RATE)));

  return {
    total: amount,
    advance,
    balance: toRupees(amount - advance),
    requiresPayment: advance > 0,
  };
}

module.exports = { splitPayment, toRupees, ADVANCE_RATE, MIN_ADVANCE };
