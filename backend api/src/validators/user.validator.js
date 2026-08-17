const { body, param } = require('express-validator');

const updateUser = [
  param('id').isInt({ min: 1 }).withMessage('Invalid user ID.'),
  body('name').optional().trim().notEmpty(),
  body('email').optional().isEmail().withMessage('Invalid email.'),
  body('current_latitude').optional().isFloat({ min: -90, max: 90 }),
  body('current_longitude').optional().isFloat({ min: -180, max: 180 }),
];

const updateProfile = [
  body('name').optional().trim().notEmpty(),
  body('email').optional().isEmail().withMessage('Invalid email.'),
  body('current_latitude').optional().isFloat({ min: -90, max: 90 }),
  body('current_longitude').optional().isFloat({ min: -180, max: 180 }),
];

const addSportPreferences = [
  body('sport_ids')
    .isArray({ min: 1 }).withMessage('sport_ids must be a non-empty array.')
    .custom((arr) => arr.every((v) => Number.isInteger(v) && v > 0))
    .withMessage('Each sport_id must be a positive integer.'),
];

module.exports = { updateUser, updateProfile, addSportPreferences };
