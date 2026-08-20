/**
 * App Version Routes — mounted at /api/v1/app-version
 *
 * The check is public: the app must be able to ask before anyone has logged in,
 * and a build old enough to be blocked has to be told so even when its stored
 * token is already rejected. Writing the thresholds is admin-only and lives in
 * adminPanel.routes.js.
 */

/**
 * @swagger
 * tags:
 *   name: AppVersion
 *   description: Mobile app version gating — public check, admin-managed thresholds
 */

const router = require('express').Router();
const validate = require('../middleware/validate');
const ctrl = require('../controllers/appVersion.controller');
const { checkVersion } = require('../validators/appVersion.validator');

/**
 * @swagger
 * /app-version:
 *   get:
 *     tags: [AppVersion]
 *     summary: Check whether the installed app build needs updating
 *     description: >
 *       Public. Compares the caller's installed version against the thresholds an
 *       admin has set for that platform. `update_available` means a newer build
 *       exists and the prompt may be dismissed; `update_required` means the build
 *       is below the minimum supported version and must be blocked. Both are false
 *       when no thresholds are configured or the check is disabled.
 *     parameters:
 *       - in: query
 *         name: platform
 *         required: true
 *         schema: { type: string, enum: [android, ios] }
 *       - in: query
 *         name: version
 *         required: true
 *         description: Installed version, e.g. 1.2.3 (a +build suffix is ignored)
 *         schema: { type: string, example: '1.2.3' }
 *     responses:
 *       200:
 *         description: Version checked
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean, example: true }
 *                 message: { type: string, example: App version checked. }
 *                 data:
 *                   type: object
 *                   properties:
 *                     platform:              { type: string,  example: android }
 *                     installed_version:     { type: string,  example: '1.2.3' }
 *                     latest_version:        { type: string,  example: '1.4.0', nullable: true }
 *                     min_supported_version: { type: string,  example: '1.2.0', nullable: true }
 *                     update_available:      { type: boolean, example: true }
 *                     update_required:       { type: boolean, example: false }
 *                     update_url:            { type: string,  nullable: true }
 *                     release_notes:         { type: string,  nullable: true }
 *       422:
 *         description: Missing or malformed platform/version
 */
router.get('/', checkVersion, validate, ctrl.check);

module.exports = router;
