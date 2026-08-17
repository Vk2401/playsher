const { body, param } = require('express-validator');

const REVIEW_TYPES = ['ground', 'sport', 'coach', 'application'];

const createReview = [
  body('review_type').isIn(REVIEW_TYPES).withMessage('Invalid review_type.'),
  body('rating')
    .isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5.'),
  body('comment').optional().trim(),
  body('ground_id').optional().isInt({ min: 1 }),
  body('ground_sport_id').optional().isInt({ min: 1 }),
  body('coach_id').optional().isInt({ min: 1 }),
  body('booking_id').optional().isInt({ min: 1 }),
];

const updateReview = [
  param('id').isInt({ min: 1 }).withMessage('Invalid review ID.'),
  body('rating').optional().isInt({ min: 1, max: 5 }),
  body('comment').optional().trim(),
];

module.exports = { createReview, updateReview };
