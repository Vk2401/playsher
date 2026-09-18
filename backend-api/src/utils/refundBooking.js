/**
 * Refunding a booking that has already been paid for — and possibly paid out.
 *
 * The hard part is not the refund, it is the order.
 *
 * A captured payment may have had the owner's share transferred to their Route
 * account already. That money is no longer ours. If we refund the customer
 * first and only then discover we cannot pull the owner's share back — because
 * it has settled to their bank, or their account is suspended — the platform
 * has funded the whole refund and the owner keeps a cut of a booking that never
 * happened. That is unrecoverable without chasing them for it.
 *
 * So: REVERSE FIRST, REFUND SECOND. If the reversal fails, nothing is refunded
 * and the caller is told why. Refusing to refund is recoverable — an admin can
 * decide to absorb it deliberately with `force` — whereas refunding money we
 * cannot claw back is not.
 *
 * The customer-facing refund itself is only issued against a real gateway
 * payment. Cash taken at the ground never passed through us and cannot be
 * refunded through us; that is reported rather than pretended.
 */
const Razorpay = require('razorpay');
const { reverseTransfer, isConfigured } = require('./razorpayRoute');
const { toPaise, toRupees } = require('./commission');

let client = null;

function getRazorpay() {
  if (client) return client;
  if (!process.env.RAZORPAY_KEY_ID || !process.env.RAZORPAY_KEY_SECRET) return null;
  client = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET,
  });
  return client;
}

/**
 * How much of the owner's share to pull back for a given refund.
 *
 * Proportional, so a half refund claws back half the share and leaves the
 * platform's fee split the same way. Computing it from the recorded
 * vendor_payout_amount rather than re-deriving from a rate keeps it consistent
 * with what was actually sent.
 */
function reversalAmount(payment, refundAmount) {
  const captured = Number(payment.amount) || 0;
  const share = Number(payment.vendor_payout_amount) || 0;
  if (!(captured > 0) || !(share > 0)) return 0;

  const refund = Number(refundAmount) || 0;
  if (refund >= captured) return share; // full refund, full reversal
  return toRupees((share * refund) / captured);
}

/**
 * Refund a payment, reversing the owner's transfer first when there is one.
 *
 * @param {object}  payment              Payment instance
 * @param {object} [options]
 * @param {number} [options.amount]      partial refund in rupees; omit for full
 * @param {boolean}[options.force]       refund even if the reversal failed
 * @param {string} [options.reason]
 * @returns {Promise<{ ok:boolean, state:string, refundId?:string, reversed?:number, message?:string }>}
 */
async function refundPayment(payment, { amount, force = false, reason } = {}) {
  if (payment.payment_status === 'refunded') {
    return { ok: false, state: 'already_refunded' };
  }
  if (payment.payment_status !== 'success') {
    return { ok: false, state: 'not_a_successful_payment' };
  }

  const captured = Number(payment.amount) || 0;
  const refundAmount = amount != null ? toRupees(amount) : captured;

  if (!(refundAmount > 0) || refundAmount > captured) {
    return { ok: false, state: 'invalid_amount' };
  }

  // Cash at the gate never reached us. Recording it as refunded here would
  // claim we returned money we never held.
  if (payment.payment_mode === 'offline' || !payment.razorpay_payment_id) {
    return { ok: false, state: 'not_a_gateway_payment' };
  }

  if (!isConfigured()) return { ok: false, state: 'gateway_not_configured' };

  // ── Step 1: get the owner's share back, before the customer is refunded ──
  let reversed = 0;
  const alreadyTransferred = Boolean(payment.transfer_id)
    && ['transferred', 'pending'].includes(payment.vendor_payout_status);

  if (alreadyTransferred) {
    const want = reversalAmount(payment, refundAmount);
    if (want > 0) {
      const rev = await reverseTransfer(payment.transfer_id, want);
      if (rev.ok) {
        reversed = want;
      } else if (!force) {
        // The owner's money is beyond reach and nobody has decided who absorbs
        // it. Stop here with the customer un-refunded rather than guessing.
        return {
          ok: false,
          state: 'reversal_failed',
          message: rev.message
            || 'Could not recover the ground owner’s share. Refund not issued.',
        };
      } else {
        console.warn('[refund] forced despite failed reversal on payment %s', payment.id);
      }
    }
  }

  // ── Step 2: refund the customer ──────────────────────────────────────────
  const razorpay = getRazorpay();
  try {
    const refund = await razorpay.payments.refund(payment.razorpay_payment_id, {
      amount: toPaise(refundAmount),
      speed: 'normal',
      notes: {
        booking_id: String(payment.booking_id),
        payment_id: String(payment.id),
        reason: reason || 'Booking refunded',
      },
    });

    await payment.update({
      // A partial refund leaves the payment successful — part of it still
      // stands — so only a full refund flips the status.
      payment_status: refundAmount >= captured ? 'refunded' : payment.payment_status,
      vendor_payout_status: reversed > 0 ? 'reversed' : payment.vendor_payout_status,
    });

    return {
      ok: true,
      state: refundAmount >= captured ? 'refunded' : 'partially_refunded',
      refundId: refund?.id,
      reversed,
    };
  } catch (err) {
    const description = err?.error?.description || err.message;
    console.error('[refund] failed for payment %s: %s', payment.id, description);
    // The reversal may already have gone through. Say so plainly: the owner's
    // share is back with us and the customer has not been paid, which needs a
    // human, not a silent retry.
    return {
      ok: false,
      state: 'refund_failed',
      reversed,
      message: reversed > 0
        ? `${description}. The owner's share of ${reversed} was already reversed and is held by the platform.`
        : description,
    };
  }
}

module.exports = { refundPayment, reversalAmount };
