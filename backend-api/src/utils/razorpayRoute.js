/**
 * Razorpay Route — the money path from a customer's card to an owner's bank.
 *
 * The shape, end to end:
 *
 *   1. Customer pays. The full amount is captured into the PLATFORM account,
 *      exactly as it is today. Nothing about checkout changes.
 *   2. We split it (utils/commission): our fee stays, the rest is the owner's.
 *   3. We create a Transfer to the owner's LINKED ACCOUNT. The money moves
 *      inside Razorpay, from our balance to theirs.
 *   4. Razorpay settles their balance to their bank on its own schedule. The
 *      owner "withdraws" by configuring that schedule, not by asking us.
 *
 * Why transfer after capture rather than splitting on the order: a pay-at-ground
 * booking is only confirmed once the advance clears, and an owner without a
 * linked account yet must still be able to take bookings. Transferring after
 * the fact lets an unonboarded owner's share sit safely in our account until
 * they finish onboarding, instead of failing their customer's payment.
 *
 * Every function here is a no-op that reports why when Razorpay is not
 * configured. The keys are still pending, and a host without them must keep
 * serving bookings — see the same reasoning in payment.controller.
 */
const Razorpay = require('razorpay');
const { splitCommission, toPaise } = require('./commission');

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

/** True when Route calls can actually reach Razorpay. */
const isConfigured = () => Boolean(getRazorpay());

/**
 * Create a Route linked account for a ground owner and store its id.
 *
 * Idempotent on our side: an owner who already has an id keeps it, so calling
 * this twice cannot strand a second account holding a share of their money.
 *
 * Razorpay still has to verify the account before transfers to it will settle;
 * `acc_...` existing means onboarding started, not that it finished.
 *
 * @param {object} owner  GroundOwner instance
 * @param {object} bank   BankDetails instance
 * @returns {Promise<{ ok:boolean, accountId?:string, reason?:string }>}
 */
async function ensureLinkedAccount(owner, bank) {
  if (owner.razorpay_linked_account_id) {
    return { ok: true, accountId: owner.razorpay_linked_account_id };
  }

  const razorpay = getRazorpay();
  if (!razorpay) return { ok: false, reason: 'gateway_not_configured' };
  if (!bank) return { ok: false, reason: 'no_bank_details' };

  try {
    const account = await razorpay.accounts.create({
      email: owner.email,
      phone: owner.mobile,
      type: 'route',
      legal_business_name: bank.account_holder_name || owner.name,
      business_type: 'individual',
      contact_name: owner.name,
      profile: { category: 'services', subcategory: 'entertainment_and_recreation' },
      legal_info: {},
    });

    await owner.update({ razorpay_linked_account_id: account.id });
    return { ok: true, accountId: account.id };
  } catch (err) {
    // Onboarding failing must never break whatever the owner was doing. Their
    // money stays in our account and is reported as awaiting onboarding.
    console.error('[route] linked account creation failed:', err?.error?.description || err.message);
    return { ok: false, reason: 'razorpay_error', message: err?.error?.description || err.message };
  }
}

/**
 * Transfer an owner's share of a captured payment to their linked account.
 *
 * Refuses rather than duplicates: a payment that already carries a transfer_id
 * is left alone. Double-transferring is the one failure here that moves real
 * money twice, and retries after a timeout are exactly when it would happen.
 *
 * On success the caller is handed the figures to persist; this function does
 * not write to the payment itself, so the amounts and the transfer id land in
 * the same transaction as everything else the caller is recording.
 *
 * @param {object} payment    Payment instance (already captured)
 * @param {string} accountId  the owner's `acc_...`
 * @returns {Promise<{ ok:boolean, transferId?:string, platformFee?:number, ownerAmount?:number, reason?:string }>}
 */
async function transferOwnerShare(payment, accountId) {
  if (payment.transfer_id) {
    return { ok: false, reason: 'already_transferred', transferId: payment.transfer_id };
  }
  if (!accountId) return { ok: false, reason: 'no_linked_account' };
  if (!payment.razorpay_payment_id) return { ok: false, reason: 'not_a_gateway_payment' };

  const { platformFee, ownerAmount } = splitCommission(payment.amount);
  if (!(ownerAmount > 0)) return { ok: false, reason: 'nothing_to_transfer' };

  const razorpay = getRazorpay();
  if (!razorpay) return { ok: false, reason: 'gateway_not_configured' };

  try {
    const transfer = await razorpay.payments.transfer(payment.razorpay_payment_id, {
      transfers: [{
        account: accountId,
        amount: toPaise(ownerAmount),
        currency: payment.currency || 'INR',
        // Carried back on the webhook, so a transfer can always be traced to
        // the booking it paid for without another lookup.
        notes: { booking_id: String(payment.booking_id), payment_id: String(payment.id) },
      }],
    });

    const created = Array.isArray(transfer?.items) ? transfer.items[0] : transfer;
    return { ok: true, transferId: created?.id, platformFee, ownerAmount };
  } catch (err) {
    console.error('[route] transfer failed:', err?.error?.description || err.message);
    return { ok: false, reason: 'razorpay_error', message: err?.error?.description || err.message };
  }
}

module.exports = { ensureLinkedAccount, transferOwnerShare, isConfigured };
