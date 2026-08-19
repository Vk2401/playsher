const router = require('express').Router();
const ctrl = require('../controllers/user.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { updateProfile, addSportPreferences } = require('../validators/user.validator');

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
 *     responses:
 *       200: { description: Updated }
 */
router.put('/', verifyToken, requireRole('user'), updateProfile, validate, ctrl.updateProfile);

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
