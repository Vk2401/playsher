const router = require('express').Router();
const ctrl = require('../controllers/sport.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { createSport, updateSport } = require('../validators/sport.validator');

/**
 * @swagger
 * tags:
 *   name: Sports
 *   description: Sport management
 */

/**
 * @swagger
 * /sports:
 *   get:
 *     tags: [Sports]
 *     summary: List active sports (public)
 *     security: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer }
 *       - in: query
 *         name: limit
 *         schema: { type: integer }
 *     responses:
 *       200: { description: List of sports }
 */
router.get('/', ctrl.list);

/**
 * @swagger
 * /sports/{id}:
 *   get:
 *     tags: [Sports]
 *     summary: Get sport by ID (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Sport detail }
 *       404: { description: Not found }
 */
router.get('/:id', ctrl.show);

/**
 * @swagger
 * /sports:
 *   post:
 *     tags: [Sports]
 *     summary: Create a sport (admin)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name]
 *             properties:
 *               name:              { type: string }
 *               short_description: { type: string }
 *               place_type:        { type: string, enum: [ground, court] }
 *               sports_type:       { type: string, enum: [indoor, outdoor] }
 *     responses:
 *       201: { description: Sport created }
 */
router.post('/', verifyToken, requireRole('admin'), createSport, validate, ctrl.create);

/**
 * @swagger
 * /sports/{id}:
 *   put:
 *     tags: [Sports]
 *     summary: Update a sport (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Updated }
 */
router.put('/:id', verifyToken, requireRole('admin'), updateSport, validate, ctrl.update);

/**
 * @swagger
 * /sports/{id}:
 *   delete:
 *     tags: [Sports]
 *     summary: Delete a sport (admin)
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
 * /sports/{id}/approve:
 *   patch:
 *     tags: [Sports]
 *     summary: Approve a sport (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Approved }
 */
router.patch('/:id/approve', verifyToken, requireRole('admin'), ctrl.approve);

module.exports = router;
