const router = require('express').Router();
const ctrl = require('../controllers/coach.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { createCoach, updateCoach } = require('../validators/coach.validator');

/**
 * @swagger
 * tags:
 *   name: Coaches
 *   description: Coach management
 */

/**
 * @swagger
 * /coaches:
 *   get:
 *     tags: [Coaches]
 *     summary: List approved coaches (public)
 *     security: []
 *     responses:
 *       200: { description: Coaches list }
 */
router.get('/', ctrl.list);

/**
 * @swagger
 * /coaches/{id}:
 *   get:
 *     tags: [Coaches]
 *     summary: Get coach by ID (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Coach detail }
 *       404: { description: Not found }
 */
router.get('/:id', ctrl.show);

/**
 * @swagger
 * /coaches:
 *   post:
 *     tags: [Coaches]
 *     summary: Create a coach (admin)
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [name, sport_id]
 *             properties:
 *               name:         { type: string }
 *               sport_id:     { type: integer }
 *               bio:          { type: string }
 *               experience:   { type: integer, description: Years of experience }
 *               hourly_rate:  { type: number }
 *               photo:        { type: string, format: binary }
 *     responses:
 *       201: { description: Coach created }
 */
router.post('/', verifyToken, requireRole('admin'), createCoach, validate, ctrl.create);

/**
 * @swagger
 * /coaches/{id}:
 *   put:
 *     tags: [Coaches]
 *     summary: Update a coach (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:        { type: string }
 *               bio:         { type: string }
 *               experience:  { type: integer }
 *               hourly_rate: { type: number }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 */
router.put('/:id', verifyToken, requireRole('admin'), updateCoach, validate, ctrl.update);

/**
 * @swagger
 * /coaches/{id}:
 *   delete:
 *     tags: [Coaches]
 *     summary: Delete a coach (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/:id', verifyToken, requireRole('admin'), ctrl.destroy);

/**
 * @swagger
 * /coaches/{id}/approve:
 *   patch:
 *     tags: [Coaches]
 *     summary: Approve a coach (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Approved }
 *       404: { description: Not found }
 */
router.patch('/:id/approve', verifyToken, requireRole('admin'), ctrl.approve);

module.exports = router;
