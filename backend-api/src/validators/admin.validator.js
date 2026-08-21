const { body, param } = require('express-validator');

const ROLES = ['super_admin', 'admin'];

// Indian mobile, matching the format the rest of the platform accepts.
const MOBILE = /^[6-9]\d{9}$/;

const adminId = param('id')
  .isInt({ min: 1 }).withMessage('Admin id must be a positive integer.');

const createAdmin = [
  body('name')
    .exists().withMessage('name is required.')
    .trim().isLength({ min: 2, max: 150 }).withMessage('name must be 2–150 characters.'),
  body('email')
    .exists().withMessage('email is required.')
    .trim().isEmail().withMessage('email must be a valid address.')
    .isLength({ max: 191 }).withMessage('email must be at most 191 characters.'),
  body('mobile')
    .exists().withMessage('mobile is required.')
    .trim().matches(MOBILE).withMessage('mobile must be a 10-digit Indian number.'),
  // Long enough to matter, since these accounts can reshape the database.
  body('password')
    .exists().withMessage('password is required.')
    .isLength({ min: 8, max: 128 }).withMessage('password must be at least 8 characters.'),
  body('role')
    .optional().isIn(ROLES).withMessage(`role must be one of ${ROLES.join(', ')}.`),
];

const updateAdmin = [
  adminId,
  body('name')
    .optional().trim().isLength({ min: 2, max: 150 }).withMessage('name must be 2–150 characters.'),
  body('email')
    .optional().trim().isEmail().withMessage('email must be a valid address.'),
  body('mobile')
    .optional().trim().matches(MOBILE).withMessage('mobile must be a 10-digit Indian number.'),
  body('role')
    .optional().isIn(ROLES).withMessage(`role must be one of ${ROLES.join(', ')}.`),
];

// Just the :id param — shared by the routes that take no body.
const adminIdOnly = [adminId];

const resetPassword = [
  adminId,
  body('new_password')
    .exists().withMessage('new_password is required.')
    .isLength({ min: 8, max: 128 }).withMessage('new_password must be at least 8 characters.'),
];

module.exports = { createAdmin, updateAdmin, adminIdOnly, resetPassword };
