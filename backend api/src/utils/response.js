/**
 * Send a standardised success response.
 * @param {import('express').Response} res
 * @param {string} message
 * @param {*} data
 * @param {number} [statusCode=200]
 * @param {object} [pagination]
 */
function success(res, message, data = null, statusCode = 200, pagination = null) {
  const body = { success: true, message };
  if (data !== null) body.data = data;
  if (pagination) body.pagination = pagination;
  return res.status(statusCode).json(body);
}

/**
 * Send a standardised error response.
 * @param {import('express').Response} res
 * @param {string} message
 * @param {number} [statusCode=400]
 * @param {Array} [errors=[]]
 */
function error(res, message, statusCode = 400, errors = []) {
  const body = { success: false, message };
  if (errors.length) body.errors = errors;
  return res.status(statusCode).json(body);
}

module.exports = { success, error };
