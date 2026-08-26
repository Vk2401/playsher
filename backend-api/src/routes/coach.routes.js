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
 *     parameters:
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: sport_id
 *         schema: { type: integer }
 *       - in: query
 *         name: sport_name
 *         schema: { type: string }
 *       - in: query
 *         name: city
 *         schema: { type: string }
 *       - in: query
 *         name: level
 *         schema: { type: string, enum: [beginner, intermediate, advanced, professional] }
 *       - in: query
 *         name: ground_id
 *         schema: { type: integer }
 *         description: Only coaches approved to coach at this ground
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Coaches list with rating, sport and approved grounds }
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
 * /coaches/{id}/slots:
 *   get:
 *     tags: [Coaches]
 *     summary: A coach's bookable 30-minute blocks for one date (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: query
 *         name: date
 *         schema: { type: string, format: date }
 *         description: Defaults to today
 *     responses:
 *       200: { description: Slot list, each with is_available }
 *       400: { description: Bad date }
 *       404: { description: Coach not found }
 */
router.get('/:id/slots', ctrl.slots);

/**
 * @swagger
 * /coaches/{id}/grounds:
 *   get:
 *     tags: [Coaches]
 *     summary: The grounds whose owners have approved this coach (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground list }
 */
router.get('/:id/grounds', ctrl.grounds);

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
