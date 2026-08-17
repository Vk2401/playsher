const { body, param } = require('express-validator');

const createBooking = [
  body('ground_sport_id').isInt({ min: 1 }).withMessage('ground_sport_id is required.'),
  body('slot_date').isDate().withMessage('slot_date must be a valid date (YYYY-MM-DD).'),
  body('slot_ids')
    .isArray({ min: 1 }).withMessage('slot_ids must be a non-empty array.')
    .custom((arr) => arr.every((v) => Number.isInteger(v) && v > 0))
    .withMessage('Each slot_id must be a positive integer.'),
  body('is_game').optional().isBoolean(),
];

const cancelBooking = [
  param('id').isInt({ min: 1 }).withMessage('Invalid booking ID.'),
  body('cancellation_reason').optional().trim(),
];

module.exports = { createBooking, cancelBooking };
