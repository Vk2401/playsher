const { body, param } = require('express-validator');

const createGround = [
  body('name').trim().notEmpty().withMessage('Ground name is required.'),
  body('address').optional().trim(),
  body('about').optional().trim(),
  body('description').optional().trim(),
  body('latitude').optional().isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude.'),
  body('longitude').optional().isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude.'),
  body('venue_rules').optional().trim(),
  // The venue's price for one 30-minute slot. Multipart sends numbers as
  // strings, so isFloat rather than isNumeric, and it may not be negative.
  body('price_per_slot').optional().isFloat({ min: 0 })
    .withMessage('price_per_slot must be a number >= 0.'),
];

const updateGround = [
  param('id').isInt({ min: 1 }).withMessage('Invalid ground ID.'),
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty.'),
  body('latitude').optional().isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude.'),
  body('longitude').optional().isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude.'),
  // The venue's price for one 30-minute slot. Multipart sends numbers as
  // strings, so isFloat rather than isNumeric, and it may not be negative.
  body('price_per_slot').optional().isFloat({ min: 0 })
    .withMessage('price_per_slot must be a number >= 0.'),
];

const addAmenities = [
  param('id').isInt({ min: 1 }).withMessage('Invalid ground ID.'),
  body('amenity_ids')
    .isArray({ min: 1 }).withMessage('amenity_ids must be a non-empty array.')
    .custom((arr) => arr.every((v) => Number.isInteger(v) && v > 0))
    .withMessage('Each amenity_id must be a positive integer.'),
];

const createGroundSport = [
  param('groundId').isInt({ min: 1 }).withMessage('Invalid ground ID.'),
  body('sport_id').isInt({ min: 1 }).withMessage('sport_id is required.'),
  body('min_slots').optional().isInt({ min: 1 }).withMessage('min_slots must be >= 1.'),
  body('max_slots').optional().isInt({ min: 1 }).withMessage('max_slots must be >= 1.'),
];

const updateGroundSport = [
  param('groundId').isInt({ min: 1 }).withMessage('Invalid ground ID.'),
  param('id').isInt({ min: 1 }).withMessage('Invalid ground-sport ID.'),
  body('min_slots').optional().isInt({ min: 1 }),
  body('max_slots').optional().isInt({ min: 1 }),
];

// Owner-panel variant: that route names its params :id and :sportId, where
// sportId is the ground_sport row id.
const updateOwnerGroundSport = [
  param('id').isInt({ min: 1 }).withMessage('Invalid ground ID.'),
  param('sportId').isInt({ min: 1 }).withMessage('Invalid ground-sport ID.'),
  body('min_slots').optional().isInt({ min: 1 }).withMessage('min_slots must be >= 1.'),
  body('max_slots').optional().isInt({ min: 1 }).withMessage('max_slots must be >= 1.'),
  body('player_counts').optional().isString(),
  body('cancellation_policy').optional().isString(),
  body('is_active').optional().isBoolean().withMessage('is_active must be a boolean.'),
];

module.exports = {
  createGround, updateGround, addAmenities,
  createGroundSport, updateGroundSport, updateOwnerGroundSport,
};
