const { body, param } = require('express-validator');

const createGround = [
  body('name').trim().notEmpty().withMessage('Ground name is required.'),
  body('address').optional().trim(),
  body('about').optional().trim(),
  body('description').optional().trim(),
  body('latitude').optional().isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude.'),
  body('longitude').optional().isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude.'),
  body('venue_rules').optional().trim(),
];

const updateGround = [
  param('id').isInt({ min: 1 }).withMessage('Invalid ground ID.'),
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty.'),
  body('latitude').optional().isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude.'),
  body('longitude').optional().isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude.'),
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
  body('price_per_half_hour').isFloat({ min: 0 }).withMessage('price_per_half_hour must be >= 0.'),
  body('min_slots').optional().isInt({ min: 1 }).withMessage('min_slots must be >= 1.'),
  body('max_slots').optional().isInt({ min: 1 }).withMessage('max_slots must be >= 1.'),
];

const updateGroundSport = [
  param('groundId').isInt({ min: 1 }).withMessage('Invalid ground ID.'),
  param('id').isInt({ min: 1 }).withMessage('Invalid ground-sport ID.'),
  body('price_per_half_hour').optional().isFloat({ min: 0 }),
  body('min_slots').optional().isInt({ min: 1 }),
  body('max_slots').optional().isInt({ min: 1 }),
];

module.exports = { createGround, updateGround, addAmenities, createGroundSport, updateGroundSport };
