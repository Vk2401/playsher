const { body } = require('express-validator');

const registerUser = [
  body('name').trim().notEmpty().withMessage('Name is required.'),
  body('mobile')
    .trim()
    .notEmpty().withMessage('Mobile is required.')
    .matches(/^\+?[0-9]{7,15}$/).withMessage('Invalid mobile number.'),
  body('email').optional({ nullable: true }).isEmail().withMessage('Invalid email address.'),
  body('password')
    .notEmpty().withMessage('Password is required.')
    .isLength({ min: 6 }).withMessage('Password must be at least 6 characters.'),
];

const loginUser = [
  body('mobile')
    .trim()
    .notEmpty().withMessage('Mobile is required.'),
  body('password').notEmpty().withMessage('Password is required.'),
];

const registerGroundOwner = [
  body('name').trim().notEmpty().withMessage('Name is required.'),
  body('email').isEmail().withMessage('Valid email is required.'),
  body('mobile')
    .trim()
    .notEmpty().withMessage('Mobile is required.')
    .matches(/^\+?[0-9]{7,15}$/).withMessage('Invalid mobile number.'),
  body('password')
    .notEmpty().withMessage('Password is required.')
    .isLength({ min: 6 }).withMessage('Password must be at least 6 characters.'),
];

const loginGroundOwner = [
  body('email').isEmail().withMessage('Valid email is required.'),
  body('password').notEmpty().withMessage('Password is required.'),
];

const registerAdmin = [
  body('name').trim().notEmpty().withMessage('Name is required.'),
  body('email').isEmail().withMessage('Valid email is required.'),
  body('mobile')
    .trim()
    .notEmpty().withMessage('Mobile is required.')
    .matches(/^\+?[0-9]{7,15}$/).withMessage('Invalid mobile number.'),
  body('password')
    .notEmpty().withMessage('Password is required.')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters.'),
  body('admin_secret').notEmpty().withMessage('Admin secret is required.'),
];

const loginAdmin = [
  body('email').isEmail().withMessage('Valid email is required.'),
  body('password').notEmpty().withMessage('Password is required.'),
];

const refreshToken = [
  body('refresh_token').notEmpty().withMessage('Refresh token is required.'),
];

module.exports = {
  registerUser,
  loginUser,
  registerGroundOwner,
  loginGroundOwner,
  registerAdmin,
  loginAdmin,
  refreshToken,
};
