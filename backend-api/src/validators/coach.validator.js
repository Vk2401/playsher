const { body, param } = require('express-validator');

const LEVELS = ['beginner', 'intermediate', 'advanced', 'professional'];

const createCoach = [
  body('name').trim().notEmpty().withMessage('Coach name is required.'),
  body('level').optional().isIn(LEVELS).withMessage('Invalid level.'),
  body('experience_years').optional().isInt({ min: 0 }),
  body('email').optional().isEmail().withMessage('Invalid email.'),
  body('mobile').optional().matches(/^\+?[0-9]{7,15}$/).withMessage('Invalid mobile number.'),
];

const updateCoach = [
  param('id').isInt({ min: 1 }).withMessage('Invalid coach ID.'),
  body('name').optional().trim().notEmpty(),
  body('level').optional().isIn(LEVELS),
  body('experience_years').optional().isInt({ min: 0 }),
  body('email').optional().isEmail(),
];

module.exports = { createCoach, updateCoach };
