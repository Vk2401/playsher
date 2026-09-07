const { body, param, query } = require('express-validator');
const { validationError } = require('../utils/username');

/**
 * A handle path parameter — a username or a numeric id.
 *
 * Loose on purpose: the controller resolves both forms, and a handle that
 * matches nothing is a 404 ("Player not found"), not a 422. Telling a caller
 * that a *well-formed* handle is invalid would be wrong, and telling them a
 * malformed one does not exist is the same answer either way.
 */
const handleParam = [
  param('handle').trim().notEmpty().isLength({ max: 40 })
    .withMessage('Invalid player handle.'),
];

const searchPlayers = [
  query('q').trim().isLength({ min: 2, max: 60 })
    .withMessage('Type at least 2 characters, or a full mobile number.'),
];

const playerId = [
  param('id').isInt({ min: 1 }).withMessage('Invalid player id.'),
];

/**
 * A username the caller is claiming.
 *
 * The reason a name is refused is written once, in `utils/username`, and passed
 * straight through — so the sentence under the field is the same sentence the
 * API would have produced, whichever path the request took.
 */
const usernameBody = [
  body('username').custom((value) => {
    const message = validationError(value);
    if (message) throw new Error(message);
    return true;
  }),
];

const usernameQuery = [
  query('username').custom((value) => {
    const message = validationError(value);
    if (message) throw new Error(message);
    return true;
  }),
];

module.exports = {
  handleParam, searchPlayers, playerId, usernameBody, usernameQuery,
};
