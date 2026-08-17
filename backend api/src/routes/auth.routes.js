const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const ctrl = require('../controllers/auth.controller');
const otpCtrl = require('../controllers/otp.controller');
const v = require('../validators/auth.validator');
const validate = require('../middleware/validate');

const authLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.AUTH_RATE_LIMIT_MAX) || 10,
  message: { success: false, message: 'Too many auth attempts, please try again later.' },
});

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Authentication endpoints
 */

/**
 * @swagger
 * /auth/admin/register:
 *   post:
 *     tags: [Auth]
 *     summary: Register first admin (requires ADMIN_SECRET)
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, email, mobile, password, admin_secret]
 *             properties:
 *               name:         { type: string }
 *               email:        { type: string, format: email }
 *               mobile:       { type: string }
 *               password:     { type: string, minLength: 8 }
 *               admin_secret: { type: string }
 *     responses:
 *       201: { description: Admin registered }
 *       400: { description: Validation error }
 *       403: { description: Invalid admin secret }
 */
router.post('/admin/register', authLimiter, v.registerAdmin, validate, ctrl.adminRegister);

/**
 * @swagger
 * /auth/admin/login:
 *   post:
 *     tags: [Auth]
 *     summary: Admin login
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password]
 *             properties:
 *               email:    { type: string, format: email }
 *               password: { type: string }
 *     responses:
 *       200: { description: Login successful }
 *       401: { description: Invalid credentials }
 */
router.post('/admin/login', authLimiter, v.loginAdmin, validate, ctrl.adminLogin);

/**
 * @swagger
 * /auth/user/register:
 *   post:
 *     tags: [Auth]
 *     summary: Register a new user
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, mobile, password]
 *             properties:
 *               name:     { type: string }
 *               mobile:   { type: string }
 *               email:    { type: string, format: email }
 *               password: { type: string, minLength: 6 }
 *     responses:
 *       201: { description: Registration successful }
 *       400: { description: Validation error }
 */
router.post('/user/register', authLimiter, v.registerUser, validate, ctrl.userRegister);

/**
 * @swagger
 * /auth/user/login:
 *   post:
 *     tags: [Auth]
 *     summary: User login (mobile + password)
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [mobile, password]
 *             properties:
 *               mobile:   { type: string }
 *               password: { type: string }
 *     responses:
 *       200: { description: Login successful }
 *       401: { description: Invalid credentials }
 */
router.post('/user/login', authLimiter, v.loginUser, validate, ctrl.userLogin);

/**
 * @swagger
 * /auth/ground-owner/register:
 *   post:
 *     tags: [Auth]
 *     summary: Register as ground owner (pending approval)
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, email, mobile, password]
 *             properties:
 *               name:     { type: string }
 *               email:    { type: string, format: email }
 *               mobile:   { type: string }
 *               password: { type: string, minLength: 6 }
 *     responses:
 *       201: { description: Registration submitted }
 */
router.post('/ground-owner/register', authLimiter, v.registerGroundOwner, validate, ctrl.groundOwnerRegister);

/**
 * @swagger
 * /auth/ground-owner/login:
 *   post:
 *     tags: [Auth]
 *     summary: Ground owner login
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password]
 *             properties:
 *               email:    { type: string, format: email }
 *               password: { type: string }
 *     responses:
 *       200: { description: Login successful }
 *       403: { description: Pending approval }
 */
router.post('/ground-owner/login', authLimiter, v.loginGroundOwner, validate, ctrl.groundOwnerLogin);

/**
 * @swagger
 * /auth/refresh-token:
 *   post:
 *     tags: [Auth]
 *     summary: Rotate refresh token
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [refresh_token]
 *             properties:
 *               refresh_token: { type: string }
 *     responses:
 *       200: { description: Token refreshed }
 *       401: { description: Invalid/expired token }
 */
router.post('/refresh-token', v.refreshToken, validate, ctrl.refreshToken);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     tags: [Auth]
 *     summary: Logout (revoke refresh token)
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               refresh_token: { type: string }
 *     responses:
 *       200: { description: Logged out }
 */
router.post('/logout', ctrl.logout);

// ── OTP-based auth (mobile app) ───────────────────────────────────────────────
const { verifyToken: authMiddleware } = require('../middleware/auth');
/**
 * @swagger
 * /auth/send-otp:
 *   post:
 *     tags: [Auth]
 *     summary: Send OTP to mobile number (mobile app)
 *     description: Creates a placeholder user record if mobile is new, then sends a 6-digit OTP (logged to console in dev).
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [mobile]
 *             properties:
 *               mobile: { type: string, example: '+919943840844' }
 *     responses:
 *       200: { description: OTP sent successfully }
 *       422: { description: mobile is required }
 */
router.post('/send-otp',              authLimiter, otpCtrl.sendOtp);

/**
 * @swagger
 * /auth/verify-otp:
 *   post:
 *     tags: [Auth]
 *     summary: Verify OTP (mobile app)
 *     description: "Validates the 6-digit OTP. Returns tokens if existing verified user, or new_user=true if profile is incomplete (call complete-registration next)."
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [mobile, otp]
 *             properties:
 *               mobile: { type: string, example: '+919943840844' }
 *               otp:    { type: string, example: '482910' }
 *     responses:
 *       200:
 *         description: "OTP verified — returns tokens (existing user) or new_user=true (new user)"
 *         content:
 *           application/json:
 *             schema:
 *               oneOf:
 *                 - type: object
 *                   properties:
 *                     success:       { type: boolean, example: true }
 *                     message:       { type: string }
 *                     data:
 *                       type: object
 *                       properties:
 *                         access_token:  { type: string }
 *                         refresh_token: { type: string }
 *                         user:
 *                           type: object
 *                           properties:
 *                             id:     { type: integer }
 *                             name:   { type: string }
 *                             mobile: { type: string }
 *                             email:  { type: string }
 *                 - type: object
 *                   properties:
 *                     success: { type: boolean, example: true }
 *                     message: { type: string }
 *                     data:
 *                       type: object
 *                       properties:
 *                         new_user: { type: boolean, example: true }
 *                         mobile:   { type: string }
 *       401: { description: Invalid or expired OTP }
 *       422: { description: mobile and otp are required }
 */
router.post('/verify-otp',            authLimiter, otpCtrl.verifyOtp);

/**
 * @swagger
 * /auth/complete-registration:
 *   post:
 *     tags: [Auth]
 *     summary: Complete profile after OTP verification (mobile app)
 *     description: Mobile must have a verified OTP (via verify-otp) before calling this. Updates the placeholder user record with real profile details and issues tokens.
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, mobile]
 *             properties:
 *               name:   { type: string, example: 'Ahmed Khan' }
 *               mobile: { type: string, example: '+919943840844' }
 *               email:  { type: string, format: email }
 *     responses:
 *       201:
 *         description: Registration complete — returns tokens
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: object
 *                   properties:
 *                     access_token:  { type: string }
 *                     refresh_token: { type: string }
 *                     user:          { type: object }
 *       403: { description: OTP not verified for this mobile }
 *       422: { description: name and mobile are required }
 */
router.post('/complete-registration', authLimiter, otpCtrl.completeRegistration);

/**
 * @swagger
 * /auth/update-location:
 *   patch:
 *     tags: [Auth]
 *     summary: Update authenticated user's current GPS location
 *     description: Saves latitude and longitude to the user's record in the database.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [latitude, longitude]
 *             properties:
 *               latitude:  { type: number, format: float, example: 28.6139 }
 *               longitude: { type: number, format: float, example: 77.2090 }
 *     responses:
 *       200: { description: Location updated }
 *       401: { description: Unauthorized }
 *       422: { description: latitude and longitude are required }
 */
router.patch('/update-location',      authMiddleware, otpCtrl.updateLocation);

module.exports = router;
