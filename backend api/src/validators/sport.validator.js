const { body, param } = require('express-validator');

const createSport = [
  body('name').trim().notEmpty().withMessage('Sport name is required.'),
  body('place_type')
    .optional()
    .isIn(['ground', 'court']).withMessage('place_type must be ground or court.'),
  body('sports_type')
    .optional()
    .isIn(['indoor', 'outdoor']).withMessage('sports_type must be indoor or outdoor.'),
];

const updateSport = [
  param('id').isInt({ min: 1 }).withMessage('Invalid sport ID.'),
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty.'),
  body('place_type')
    .optional()
    .isIn(['ground', 'court']).withMessage('place_type must be ground or court.'),
  body('sports_type')
    .optional()
    .isIn(['indoor', 'outdoor']).withMessage('sports_type must be indoor or outdoor.'),
];

module.exports = { createSport, updateSport };
