const { BankDetails } = require('../models');
const { success, error } = require('../utils/response');

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

    return success(res, created ? 'Bank details saved.' : 'Bank details updated.', details, created ? 201 : 200);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
