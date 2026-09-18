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
 * Creating a transfer is not the same as it landing. Everything here reports
 * what it *did*; what actually happened arrives later on the webhook
 * (controllers/webhook.controller), which is the only thing that writes
 * `transferred`, `failed` or `reversed` as a final state.
 *
 * Every function is a no-op that reports why when Razorpay is not configured.
 * The keys are still pending, and a host without them must keep serving
 * bookings — see the same reasoning in payment.controller.
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

/** The only account state money can be sent to. */
const ACTIVATED = 'activated';

/**
 * Onboard a ground owner as a Route linked account.
 *
 * Two calls, because Razorpay splits them: the account carries who they are,
 * and a separate product configuration carries where their money settles. An
 * account without the `route` product configured can exist and still not
 * receive transfers.
 *
 * Idempotent on our side: an owner who already has an id keeps it, so calling
 * this twice cannot strand a second account holding a share of their money.
 *
 * `acc_...` existing means onboarding started. Razorpay verifies the details
 * afterwards and reports the outcome on the `account.*` webhooks, which is what
 * moves `razorpay_account_status` to `activated`.
 *
 * @param {object} owner  GroundOwner instance
 * @param {object} bank   BankDetails instance
 * @returns {Promise<{ ok:boolean, accountId?:string, status?:string, reason?:string }>}
 */
async function ensureLinkedAccount(owner, bank) {
  if (owner.razorpay_linked_account_id) {
    return {
      ok: true,
      accountId: owner.razorpay_linked_account_id,
      status: owner.razorpay_account_status || 'created',
    };
  }

  const razorpay = getRazorpay();
  if (!razorpay) return { ok: false, reason: 'gateway_not_configured' };
  if (!bank) return { ok: false, reason: 'no_bank_details' };
  if (!bank.account_number || !bank.ifsc_code) return { ok: false, reason: 'incomplete_bank_details' };

  try {
    // Razorpay requires a reference id unique per account. The owner id is
    // stable and already unique, and prefixing keeps it readable in their
    // dashboard next to accounts created by anything else.
    const account = await razorpay.accounts.create({
      email: owner.email,
      phone: String(owner.mobile || '').replace(/\D/g, '').slice(-10),
      type: 'route',
      reference_id: `playsher_owner_${owner.id}`,
      legal_business_name: (bank.account_holder_name || owner.name || '').slice(0, 200),
      business_type: 'individual',
      contact_name: owner.name,
      profile: {
        category: 'services',
        subcategory: 'entertainment_and_recreation',
        addresses: {
          registered: {
            street1: 'Not provided',
            street2: '',
            city: 'Not provided',
            state: 'Not provided',
            postal_code: '000000',
            country: 'IN',
          },
        },
      },
      legal_info: {},
    });

    await owner.update({
      razorpay_linked_account_id: account.id,
      // Trust Razorpay's own word on the state when it gives one, rather than
      // assuming 'created' and having to reconcile it later.
      razorpay_account_status: account.status || 'created',
    });

    // Settlement destination. Without this the account exists but has nowhere
    // to send money on, and transfers sit in its balance indefinitely.
    try {
      await razorpay.products.requestProductConfiguration(account.id, {
        product_name: 'route',
        tnc_accepted: true,
        settlements: {
          account_number: bank.account_number,
          ifsc_code: bank.ifsc_code,
          beneficiary_name: bank.account_holder_name || owner.name,
        },
      });
    } catch (cfgErr) {
      // The account is real and stored; only the settlement leg failed. Say so
      // rather than discarding an account we would then re-create.
      console.error('[route] product configuration failed for %s: %s',
        account.id, cfgErr?.error?.description || cfgErr.message);
      return { ok: true, accountId: account.id, status: 'needs_clarification' };
    }

    return { ok: true, accountId: account.id, status: account.status || 'created' };
  } catch (err) {
    // Onboarding failing must never break whatever the owner was doing. Their
    // money stays in our account and is reported as awaiting onboarding.
    console.error('[route] linked account creation failed:', err?.error?.description || err.message);
    return { ok: false, reason: 'razorpay_error', message: err?.error?.description || err.message };
  }
}

/**
 * Re-read an account's state from Razorpay and store it.
 *
 * The webhook is the normal path; this is for a retry, or for an account
 * onboarded before the webhook existed.
 */
async function refreshAccountStatus(owner) {
  if (!owner.razorpay_linked_account_id) return { ok: false, reason: 'no_linked_account' };
  const razorpay = getRazorpay();
  if (!razorpay) return { ok: false, reason: 'gateway_not_configured' };

  try {
    const account = await razorpay.accounts.fetch(owner.razorpay_linked_account_id);
    if (account?.status && account.status !== owner.razorpay_account_status) {
      await owner.update({ razorpay_account_status: account.status });
    }
    return { ok: true, status: account?.status || owner.razorpay_account_status };
  } catch (err) {
    console.error('[route] account fetch failed:', err?.error?.description || err.message);
    return { ok: false, reason: 'razorpay_error' };
  }
}

/**
 * Transfer an owner's share of a captured payment to their linked account.
 *
 * Refuses rather than duplicates: a payment that already carries a transfer_id
 * is left alone. Double-transferring is the one failure here that moves real
 * money twice, and retries after a timeout are exactly when it would happen.
 *
 * Refuses an account that is not activated. Razorpay would reject it anyway,
 * but failing here keeps the reason readable instead of turning it into a
 * generic gateway error a week later.
 *
 * @param {object} payment    Payment instance (already captured)
 * @param {string} accountId  the owner's `acc_...`
 * @param {object} [opts]
 * @param {string} [opts.accountStatus]
 * @returns {Promise<{ ok:boolean, transferId?:string, platformFee?:number, ownerAmount?:number, reason?:string }>}
 */
async function transferOwnerShare(payment, accountId, { accountStatus } = {}) {
  if (payment.transfer_id) {
    return { ok: false, reason: 'already_transferred', transferId: payment.transfer_id };
  }
  if (!accountId) return { ok: false, reason: 'no_linked_account' };
  if (accountStatus && accountStatus !== ACTIVATED) {
    return { ok: false, reason: 'account_not_activated' };
  }
  if (!payment.razorpay_payment_id) return { ok: false, reason: 'not_a_gateway_payment' };

  // Prefer the amount already recorded on the payment over recomputing it.
  // settleCapturedPayment writes vendor_payout_amount before calling this, and
  // a retry days later must send exactly that figure — not whatever the rate
  // happens to be now. The recompute is only for a payment written before the
  // ledger columns were populated.
  const recorded = payment.vendor_payout_amount != null ? Number(payment.vendor_payout_amount) : null;
  const fallback = splitCommission(payment.amount);
  const ownerAmount = recorded != null && recorded > 0 ? recorded : fallback.ownerAmount;
  const platformFee = payment.platform_fee != null ? Number(payment.platform_fee) : fallback.platformFee;

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

/**
 * Pull an owner's share back out of their linked account.
 *
 * Needed whenever a booking is refunded after its transfer went out: the
 * customer's money comes from the platform account, but the owner's share is
 * already sitting with the owner. Without a reversal the platform funds the
 * refund alone and the owner keeps a cut of a booking that did not happen.
 *
 * Partial reversal is supported so a partial refund does not claw back the
 * whole share. Omitting the amount reverses all of it.
 *
 * This can genuinely fail with insufficient balance — an owner whose money has
 * already settled to their bank has nothing left in the Route balance to
 * reverse. That is a real business situation, reported rather than swallowed.
 *
 * @param {string} transferId
 * @param {number} [amountRupees]  omit to reverse the full transfer
 */
async function reverseTransfer(transferId, amountRupees) {
  if (!transferId) return { ok: false, reason: 'no_transfer' };
  const razorpay = getRazorpay();
  if (!razorpay) return { ok: false, reason: 'gateway_not_configured' };

  try {
    const body = amountRupees != null ? { amount: toPaise(amountRupees) } : {};
    const reversal = await razorpay.transfers.reverse(transferId, body);
    return { ok: true, reversalId: reversal?.id, amount: amountRupees ?? null };
  } catch (err) {
    const description = err?.error?.description || err.message;
    console.error('[route] reversal failed for %s: %s', transferId, description);
    return { ok: false, reason: 'razorpay_error', message: description };
  }
}

module.exports = {
  ensureLinkedAccount,
  refreshAccountStatus,
  transferOwnerShare,
  reverseTransfer,
  isConfigured,
  ACTIVATED,
};
