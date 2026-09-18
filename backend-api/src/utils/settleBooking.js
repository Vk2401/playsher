/**
 * What happens to the money once a payment clears.
 *
 * Kept out of payment.controller because the same settlement has to run from
 * more than one place — signature verification today, a Razorpay webhook and an
 * admin retry next — and a second copy of a money path is how two of them drift
 * apart. Route every new "the payment succeeded" branch through here.
 *
 * The order is deliberate. The fee and the owner's share are recorded FIRST,
 * from the captured amount, and only then is the transfer attempted. If the
 * transfer fails or Razorpay is not configured, the ledger still says exactly
 * what is owed to whom — the money is simply still sitting in our account,
 * flagged for a retry, rather than unaccounted for.
 */
const { splitCommission } = require('./commission');
const { ensureLinkedAccount, transferOwnerShare, isConfigured } = require('./razorpayRoute');

/**
 * Record the split for a captured payment and move the owner's share if it can.
 *
 * Never throws: the customer has already paid by the time this runs, and a
 * failure here must not turn a successful payment into an error response.
 *
 * @param {object}  models              { Payment, Booking, GroundSport, Ground, GroundOwner, BankDetails }
 * @param {object}  payment             the captured Payment instance
 * @param {object} [options]
 * @param {object} [options.transaction]
 * @returns {Promise<{ state:string, platformFee:number, ownerAmount:number, transferId?:string }>}
 */
async function settleCapturedPayment(models, payment, { transaction } = {}) {
  const { Booking, GroundSport, Ground, GroundOwner, BankDetails } = models;

  const { platformFee, ownerAmount } = splitCommission(payment.amount);

  // Persist the split whatever happens next. This is the number the owner's
  // Earnings screen and any later reconciliation both read.
  const ledger = {
    platform_fee: platformFee,
    vendor_payout_amount: ownerAmount,
  };

  try {
    const booking = await Booking.findByPk(payment.booking_id, {
      include: [{
        model: GroundSport,
        as: 'groundSport',
        include: [{ model: Ground, as: 'ground' }],
      }],
      transaction,
    });

    const ownerId = booking?.groundSport?.ground?.owner_id;
    if (!ownerId) {
      await payment.update({ ...ledger, vendor_payout_status: 'no_vendor' }, { transaction });
      return { state: 'no_vendor', platformFee, ownerAmount };
    }

    if (!isConfigured()) {
      // Nothing can move yet. Say so honestly rather than reporting 'pending'
      // forever, which is what the old admin-written column did.
      await payment.update({ ...ledger, vendor_payout_status: 'pending' }, { transaction });
      return { state: 'gateway_not_configured', platformFee, ownerAmount };
    }

    const owner = await GroundOwner.findByPk(ownerId, { transaction });
    const bank = await BankDetails.findOne({
      where: { user_id: ownerId, user_type: 'ground_owner' },
      transaction,
    });

    if (!bank) {
      await payment.update({ ...ledger, vendor_payout_status: 'no_bank_details' }, { transaction });
      return { state: 'no_bank_details', platformFee, ownerAmount };
    }

    const account = await ensureLinkedAccount(owner, bank);
    if (!account.ok) {
      await payment.update({ ...ledger, vendor_payout_status: 'no_bank_details' }, { transaction });
      return { state: account.reason, platformFee, ownerAmount };
    }

    const result = await transferOwnerShare(payment, account.accountId);
    if (!result.ok) {
      // Left 'pending' on purpose: the share is genuinely still ours to send,
      // and a retry should pick it up rather than skip it.
      await payment.update({ ...ledger, vendor_payout_status: 'pending' }, { transaction });
      return { state: result.reason, platformFee, ownerAmount };
    }

    await payment.update({
      ...ledger,
      transfer_id: result.transferId,
      vendor_payout_status: 'transferred',
    }, { transaction });

    return { state: 'transferred', platformFee, ownerAmount, transferId: result.transferId };
  } catch (err) {
    console.error('[settle] failed for payment', payment.id, err.message);
    // Still record what is owed. An unsettled payment we can see is recoverable;
    // one with no split recorded is not.
    try {
      await payment.update({ ...ledger, vendor_payout_status: 'pending' }, { transaction });
    } catch (inner) {
      console.error('[settle] could not record split for payment', payment.id, inner.message);
    }
    return { state: 'error', platformFee, ownerAmount };
  }
}

module.exports = { settleCapturedPayment };
