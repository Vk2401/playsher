const { BankDetails, GroundOwner } = require('../models');
const { success, error } = require('../utils/response');
const { ensureLinkedAccount, isConfigured } = require('../utils/razorpayRoute');

/** GET /bank-details — get current user's bank details */
exports.get = async (req, res) => {
  try {
    const details = await BankDetails.findOne({
      where: { user_id: req.user.id, user_type: req.user.role },
    });
    return success(res, details ? 'Bank details retrieved.' : 'No bank details found.', details);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** POST /add-bank-details — create or update bank details */
exports.save = async (req, res) => {
  try {
    const { account_holder_name, account_number, ifsc_code, bank_name, upi_id } = req.body;
    if (!account_holder_name || !account_number || !ifsc_code) {
      return error(res, 'account_holder_name, account_number and ifsc_code are required.', 422);
    }

    const [details, created] = await BankDetails.findOrCreate({
      where: { user_id: req.user.id, user_type: req.user.role },
      defaults: {
        user_id: req.user.id,
        user_type: req.user.role,
        account_holder_name,
        account_number,
        ifsc_code,
        bank_name: bank_name || null,
        upi_id: upi_id || null,
      },
    });

    if (!created) {
      await details.update({ account_holder_name, account_number, ifsc_code, bank_name, upi_id });
    }

    // Saving bank details IS the onboarding trigger. A ground owner should not
    // have to find a second button to become payable, and until Route has a
    // linked account for them their share of every payment stays in the
    // platform account marked `no_bank_details`.
    //
    // Deliberately not awaited into the response path: Razorpay being slow or
    // down must not make saving a bank account fail. The next payment settles
    // it anyway, because settleCapturedPayment calls ensureLinkedAccount too.
    let payoutOnboarding = 'not_applicable';
    if (req.user.role === 'ground_owner') {
      if (!isConfigured()) {
        payoutOnboarding = 'gateway_not_configured';
      } else {
        const owner = await GroundOwner.findByPk(req.user.id);
        const account = owner ? await ensureLinkedAccount(owner, details) : { ok: false, reason: 'no_owner' };
        payoutOnboarding = account.ok ? 'linked' : account.reason;
      }
    }

    return success(
      res,
      created ? 'Bank details saved.' : 'Bank details updated.',
      { ...details.toJSON(), payout_onboarding: payoutOnboarding },
      created ? 201 : 200,
    );
  } catch (err) {
    return error(res, err.message, 500);
  }
};
