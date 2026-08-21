/**
 * Database schema routes — mounted at /api/v1/admin/schema
 *
 * Admin only, and admin only on the server: these endpoints reshape tables, so
 * the sidebar entry being hidden from other roles is presentation, not security.
 */

/**
 * @swagger
 * tags:
 *   name: Schema
 *   description: Database schema definition and sync (requires admin role)
 */

const router = require('express').Router();
const { param, body } = require('express-validator');

const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const ctrl = require('../controllers/schema.controller');

const admin = [verifyToken, requireRole('admin')];

/**
 * @swagger
 * /admin/schema:
 *   get:
 *     tags: [Schema]
 *     summary: Get the schema definition (database/schema.json)
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200:
 *         description: The declared schema, with per-table counts
 *       403: { description: Admin role required }
 */
router.get('/', admin, ctrl.getDefinition);

/**
 * @swagger
 * /admin/schema/plan:
 *   get:
 *     tags: [Schema]
 *     summary: Preview the changes needed to make the database match schema.json
 *     description: >
 *       Read-only dry run. Returns operations classified as `safe` or `risky`,
 *       plus `blocked` changes that cannot be applied without data loss and
 *       `extras` — tables or columns present in the database but absent from the
 *       JSON, which are never touched.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: The plan }
 *       403: { description: Admin role required }
 */
router.get('/plan', admin, ctrl.getPlan);

/**
 * @swagger
 * /admin/schema/apply:
 *   post:
 *     tags: [Schema]
 *     summary: Apply the schema plan to the database
 *     description: >
 *       Starts an asynchronous sync and returns a job id to poll. Safe
 *       operations run by default; risky ones (narrowing a column, tightening
 *       NULL to NOT NULL) only when `include_risky` is true. Nothing is ever
 *       dropped.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               include_risky:
 *                 type: boolean
 *                 default: false
 *     responses:
 *       202: { description: Sync started, job id returned }
 *       200: { description: Already in sync, nothing to do }
 *       403: { description: Admin role required }
 */
router.post(
  '/apply',
  admin,
  body('include_risky').optional().isBoolean().withMessage('include_risky must be a boolean'),
  validate,
  ctrl.apply
);

/**
 * @swagger
 * /admin/schema/jobs/{id}:
 *   get:
 *     tags: [Schema]
 *     summary: Get sync job progress
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Job status, percent complete and per-step results }
 *       404: { description: Job not found }
 */
router.get(
  '/jobs/:id',
  admin,
  param('id').isInt({ min: 1 }).withMessage('Job id must be a positive integer'),
  validate,
  ctrl.getJobStatus
);

module.exports = router;
