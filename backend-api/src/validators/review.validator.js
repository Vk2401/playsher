const { body, param, query } = require('express-validator');

const REVIEW_TYPES = ['ground', 'sport', 'coach', 'application'];

const createReview = [
  body('review_type').isIn(REVIEW_TYPES).withMessage('Invalid review_type.'),
  // Required for a venue review: the controller resolves the qualifying
  // booking from the ground, so without it there is nothing to check against.
  body('ground_id')
    .if(body('review_type').isIn(['ground', 'sport']))
    .isInt({ min: 1 }).withMessage('ground_id is required for a venue review.'),
  body('rating')
    .isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5.'),
  body('comment').optional().trim(),
  body('ground_sport_id').optional().isInt({ min: 1 }),
  body('coach_id').optional().isInt({ min: 1 }),
  // booking_id is deliberately not accepted: the controller resolves the
  // qualifying booking itself, and trusting a client-supplied id is what let
  // the eligibility check be skipped.
];

const reviewEligibility = [
  query('ground_id').isInt({ min: 1 }).withMessage('ground_id is required.'),
];

const updateReview = [
  param('id').isInt({ min: 1 }).withMessage('Invalid review ID.'),
  body('rating').optional().isInt({ min: 1, max: 5 }),
  body('comment').optional().trim(),
];

module.exports = { createReview, updateReview, reviewEligibility };
