const crypto = require('crypto');
const { Payment, GroundOwner } = require('../models');

/**
 * Razorpay webhooks — the only place that records what actually happened.
 *
 * Everything else in the payout path reports what it *asked for*. Creating a
 * transfer is a request; Razorpay can still fail it, reverse it, or take days
 * to verify the account it was going to. Without this endpoint
 * `vendor_payout_status` would say "transferred" for money that never landed,
 * which is the worst kind of wrong: confidently wrong, in the ledger.
 *
 * Three rules this endpoint follows, in order of how badly they bite:
 *
 *   1. Verify the signature before reading anything. The body is attacker
 *      controlled until it is verified, and this endpoint writes to the payout
 *      ledger — an unauthenticated caller must not be able to mark payouts
 *      settled. Compared with timingSafeEqual, not `===`.
 *
 *   2. Answer 200 for anything understood, including events acted on as no-ops.
 *      Razorpay retries non-2xx for 24 hours; a 500 on an event we cannot use
 *      turns one bad payload into a day of noise.
 *
 *   3. Be idempotent. Retries are normal and duplicates are guaranteed. Every
 *      handler writes a terminal state rather than incrementing anything, so
 *      the tenth delivery leaves the same row as the first.
 *
 * Configure in the Razorpay dashboard against POST /api/v1/webhooks/razorpay
 * with RAZORPAY_WEBHOOK_SECRET, subscribing to: transfer.processed,
 * transfer.failed, transfer.reversed, account.activated, account.suspended,
 * account.needs_clarification.
 */

/** Razorpay signs the raw body with the webhook secret, not the API secret. */
function verifySignature(req) {
  const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
  if (!secret) return { ok: false, reason: 'not_configured' };

  const signature = req.get('x-razorpay-signature');
  if (!signature) return { ok: false, reason: 'missing_signature' };

  // The exact bytes received. JSON.stringify of the parsed object is not
  // byte-identical to what was sent, so app.js keeps the raw buffer.
  const raw = req.rawBody;
  if (!raw) return { ok: false, reason: 'missing_raw_body' };

  const expected = crypto.createHmac('sha256', secret).update(raw).digest('hex');

  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(signature, 'utf8');
  // timingSafeEqual throws on a length mismatch, so check that first.
  if (a.length !== b.length) return { ok: false, reason: 'bad_signature' };
  if (!crypto.timingSafeEqual(a, b)) return { ok: false, reason: 'bad_signature' };

  return { ok: true };
}

/** Find the payment a transfer belongs to, by id or by the notes we attached. */
async function paymentForTransfer(transfer) {
  if (transfer?.id) {
    const byTransfer = await Payment.findOne({ where: { transfer_id: transfer.id } });
    if (byTransfer) return byTransfer;
  }
  const noted = transfer?.notes?.payment_id;
  if (noted) return Payment.findByPk(noted);
  return null;
}

const handlers = {
  /** The owner's share actually landed in their linked account. */
  async 'transfer.processed'(payload) {
    const transfer = payload?.transfer?.entity;
    const payment = await paymentForTransfer(transfer);
    if (!payment) return 'no_matching_payment';

    await payment.update({
      transfer_id: transfer.id,
      vendor_payout_status: 'transferred',
    });
    return 'marked_transferred';
  },

  /**
   * Razorpay could not complete it. The money is still ours, so the status has
   * to say so — and `failed` rather than `pending`, because pending reads as
   * "on its way" and nobody would go looking at it.
   */
  async 'transfer.failed'(payload) {
    const transfer = payload?.transfer?.entity;
    const payment = await paymentForTransfer(transfer);
    if (!payment) return 'no_matching_payment';

    await payment.update({ vendor_payout_status: 'failed' });
    console.warn('[webhook] transfer %s failed for payment %s', transfer?.id, payment.id);
    return 'marked_failed';
  },

  /** Pulled back out of the owner's account, normally because of a refund. */
  async 'transfer.reversed'(payload) {
    const transfer = payload?.transfer?.entity;
    const payment = await paymentForTransfer(transfer);
    if (!payment) return 'no_matching_payment';

    await payment.update({ vendor_payout_status: 'reversed' });
    return 'marked_reversed';
  },

  /** The owner can now receive money. Their held share is transferable. */
  async 'account.activated'(payload) {
    const account = payload?.account?.entity;
    const owner = await GroundOwner.findOne({
      where: { razorpay_linked_account_id: account?.id },
    });
    if (!owner) return 'no_matching_owner';

    await owner.update({ razorpay_account_status: 'activated' });
    return 'owner_activated';
  },

  async 'account.suspended'(payload) {
    const account = payload?.account?.entity;
    const owner = await GroundOwner.findOne({
      where: { razorpay_linked_account_id: account?.id },
    });
    if (!owner) return 'no_matching_owner';

    await owner.update({ razorpay_account_status: 'suspended' });
    return 'owner_suspended';
  },

  async 'account.needs_clarification'(payload) {
    const account = payload?.account?.entity;
    const owner = await GroundOwner.findOne({
      where: { razorpay_linked_account_id: account?.id },
    });
    if (!owner) return 'no_matching_owner';

    await owner.update({ razorpay_account_status: 'needs_clarification' });
    return 'owner_needs_clarification';
  },
};

/** POST /webhooks/razorpay */
exports.razorpay = async (req, res) => {
  const check = verifySignature(req);
  if (!check.ok) {
    console.warn('[webhook] rejected: %s', check.reason);
    // 401 without detail. A caller probing this endpoint learns only that it
    // refused them, not which part of the signature was wrong.
    return res.status(401).json({ success: false, message: 'Invalid signature.' });
  }

  const event = req.body?.event;
  const handler = handlers[event];

  try {
    if (!handler) {
      // Subscribed to something we do not act on, or Razorpay added an event.
      // Acknowledge it — retrying for a day would not make us understand it.
      return res.status(200).json({ success: true, message: 'Ignored.', event });
    }

    const outcome = await handler(req.body?.payload || {});
    return res.status(200).json({ success: true, message: 'Handled.', event, outcome });
  } catch (err) {
    // A genuine failure on our side. 500 so Razorpay retries: a transfer
    // outcome lost to a transient database error is a ledger that stays wrong.
    console.error('[webhook] handler for %s threw: %s', event, err.message);
    return res.status(500).json({ success: false, message: 'Handler failed.' });
  }
};

// Exported for the self-check.
exports._verifySignature = verifySignature;
exports._handlers = handlers;
