const router = require('express').Router();
const ctrl = require('../controllers/user.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { updateProfile, addSportPreferences } = require('../validators/user.validator');
const { usernameBody, usernameQuery } = require('../validators/player.validator');

/**
 * @swagger
 * tags:
 *   name: Profile
 *   description: Authenticated user's own profile
 */

/**
 * @swagger
 * /profile:
 *   get:
 *     tags: [Profile]
 *     summary: Get own profile
 *     responses:
 *       200: { description: Profile data }
 */
router.get('/', verifyToken, requireRole('user'), ctrl.getProfile);

/**
 * @swagger
 * /profile:
 *   put:
 *     tags: [Profile]
 *     summary: Update own profile
 *     description: >
 *       `name`, `email`, `profile_picture` and `bio` only. The username has its
 *       own endpoint, and `mobile` is the login identity — changing it goes
 *       through OTP re-verification, not a profile PUT.
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:            { type: string }
 *               email:           { type: string, format: email }
 *               profile_picture: { type: string }
 *               bio:             { type: string, maxLength: 160 }
 *     responses:
 *       200: { description: Updated }
 */
router.put('/', verifyToken, requireRole('user'), updateProfile, validate, ctrl.updateProfile);

/**
 * @swagger
 * /profile/username-available:
 *   get:
 *     tags: [Profile]
 *     summary: Is this username free?
 *     description: >
 *       Advisory, for the field under the input while somebody types. Two
 *       people can pass this in the same second, so the unique index is what
 *       actually decides — `PATCH /profile/username` answers 409 if the name
 *       was claimed in between. A malformed name answers 200 with
 *       `available: false` and the reason, because "not usable" is the same
 *       answer the field needs either way.
 *     parameters:
 *       - in: query
 *         name: username
 *         required: true
 *         schema: { type: string, minLength: 3, maxLength: 30 }
 *     responses:
 *       200:
 *         description: Availability plus the reason when it is not free
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     username:  { type: string }
 *                     available: { type: boolean }
 *                     reason:    { type: string, nullable: true }
 */
router.get('/username-available', verifyToken, requireRole('user'), usernameQuery, validate, ctrl.checkUsername);

/**
 * @swagger
 * /profile/username:
 *   patch:
 *     tags: [Profile]
 *     summary: Claim a username
 *     description: >
 *       Lowercase letters, digits and single underscores; 3–30 characters; at
 *       least one letter; not reserved. Stored and compared lowercase, so two
 *       accounts can never differ only by case.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [username]
 *             properties:
 *               username: { type: string, example: ravi_99 }
 *     responses:
 *       200: { description: Username updated }
 *       400: { description: The name breaks a rule — the message says which }
 *       409: { description: Somebody else holds that name }
 */
router.patch('/username', verifyToken, requireRole('user'), usernameBody, validate, ctrl.setUsername);

/**
 * @swagger
 * /profile/sport-preferences:
 *   post:
 *     tags: [Profile]
 *     summary: Add sport preferences
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [sport_ids]
 *             properties:
 *               sport_ids:
 *                 type: array
 *                 items: { type: integer }
 *     responses:
 *       200: { description: Preferences added }
 */
router.post('/sport-preferences', verifyToken, requireRole('user'), addSportPreferences, validate, ctrl.addSportPreferences);

/**
 * @swagger
 * /profile/sport-preferences/{sportId}:
 *   delete:
 *     tags: [Profile]
 *     summary: Remove a sport preference
 *     parameters:
 *       - in: path
 *         name: sportId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Removed }
 */
router.delete('/sport-preferences/:sportId', verifyToken, requireRole('user'), ctrl.removeSportPreference);

module.exports = router;
