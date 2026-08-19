const { validationResult } = require('express-validator');
const { error } = require('../utils/response');

/**
 * Run after express-validator chains; returns 422 with formatted errors on failure.
 */
function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return error(
      res,
      'Validation failed.',
      422,
      errors.array().map((e) => ({ field: e.path, message: e.msg }))
    );
  }
  next();
}

module.exports = validate;
