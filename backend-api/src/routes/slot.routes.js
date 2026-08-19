const router = require('express').Router({ mergeParams: true });
const ctrl = require('../controllers/slot.controller');
const { verifyToken, requireRole } = require('../middleware/auth');

/**
 * @swagger
 * tags:
 *   name: Slots
 *   description: Slot management for a ground sport
 */

/**
 * @swagger
 * /ground-sports/{gsId}/slots:
 *   get:
 *     tags: [Slots]
 *     summary: List slots for a ground sport (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: gsId
 *         required: true
 *         schema: { type: integer }
 *       - in: query
 *         name: date
 *         schema: { type: string, format: date }
 *     responses:
 *       200: { description: Slots list }
 */
router.get('/', ctrl.list);
/**
 * @swagger
 * /ground-sports/{gsId}/slots:
 *   post:
 *     tags: [Slots]
 *     summary: Create a slot for a ground sport (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: gsId
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [start_time, end_time, day_of_week]
 *             properties:
 *               start_time:  { type: string, example: '08:00', description: HH:MM format }
 *               end_time:    { type: string, example: '09:00', description: HH:MM format }
 *               day_of_week: { type: integer, minimum: 0, maximum: 6, description: 0=Sunday … 6=Saturday }
 *               is_available: { type: boolean }
 *     responses:
 *       201: { description: Slot created }
 *       400: { description: Validation error }
 */
router.post('/', verifyToken, requireRole('ground_owner', 'admin'), ctrl.create);

/**
 * @swagger
 * /ground-sports/{gsId}/slots/{id}:
 *   put:
 *     tags: [Slots]
 *     summary: Update a slot (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: gsId
 *         required: true
 *         schema: { type: integer }
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
 *               start_time:   { type: string }
 *               end_time:     { type: string }
 *               day_of_week:  { type: integer }
 *               is_available: { type: boolean }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 */
router.put('/:id', verifyToken, requireRole('ground_owner', 'admin'), ctrl.update);

/**
 * @swagger
 * /ground-sports/{gsId}/slots/{id}:
 *   delete:
 *     tags: [Slots]
 *     summary: Delete a slot (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: gsId
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/:id', verifyToken, requireRole('ground_owner', 'admin'), ctrl.destroy);

module.exports = router;
