const { body } = require('express-validator');
const { normalizeIndianMobile } = require('../utils/mobile.utils');

// Indian mobile only: 10 digits starting 6-9, normalised to +91XXXXXXXXXX.
// Mirrors the Flutter validator in mobile_app/lib/screens/phone_screen.dart.
const indianMobile = () =>
  body('mobile')
    .trim()
    .notEmpty().withMessage('Mobile is required.')
    .customSanitizer((v) => normalizeIndianMobile(v) ?? v)
    .matches(/^\+91[6-9]\d{9}$/)
    .withMessage('Enter a valid 10-digit Indian mobile number starting with 6, 7, 8 or 9.');

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

const sendOtp = [indianMobile()];

const verifyOtp = [
  indianMobile(),
  body('otp')
    .trim()
    .notEmpty().withMessage('OTP is required.')
    .matches(/^\d{6}$/).withMessage('OTP must be 6 digits.'),
];

const completeRegistration = [
  indianMobile(),
  body('name').trim().notEmpty().withMessage('Name is required.'),
  body('email').optional({ nullable: true, checkFalsy: true })
    .isEmail().withMessage('Invalid email address.'),
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
  sendOtp,
  verifyOtp,
  completeRegistration,
};
