const { body, param } = require('express-validator');

const createCoachBooking = [
  body('coach_id').isInt({ min: 1 }).withMessage('A coach is required.'),
  body('ground_id').optional({ nullable: true }).isInt({ min: 1 }).withMessage('Invalid ground.'),
  body('session_date')
    .matches(/^\d{4}-\d{2}-\d{2}$/).withMessage('session_date must be YYYY-MM-DD.'),
  body('slot_ids')
    .isArray({ min: 1 }).withMessage('Pick at least one time slot.'),
  body('slot_ids.*').isInt({ min: 1 }).withMessage('Invalid slot.'),
  body('customer_note').optional({ nullable: true }).isLength({ max: 500 })
    .withMessage('Keep the note under 500 characters.'),
];

const cancelCoachBooking = [
  param('id').isInt({ min: 1 }).withMessage('Invalid session ID.'),
  body('cancellation_reason').optional({ nullable: true }).isLength({ max: 500 })
    .withMessage('Keep the reason under 500 characters.'),
];

module.exports = { createCoachBooking, cancelCoachBooking };
