const { body, param } = require('express-validator');

const createAmenity = [
  body('name').trim().notEmpty().withMessage('Amenity name is required.'),
  body('type')
    .optional()
    .isIn(['venue', 'sport']).withMessage('type must be venue or sport.'),
  body('icon').optional().trim(),
];

const updateAmenity = [
  param('id').isInt({ min: 1 }).withMessage('Invalid amenity ID.'),
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty.'),
  body('type').optional().isIn(['venue', 'sport']),
];

module.exports = { createAmenity, updateAmenity };
