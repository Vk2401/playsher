const router = require('express').Router();
const ctrl = require('../controllers/review.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { createReview, updateReview } = require('../validators/review.validator');

/**
 * @swagger
 * tags:
 *   name: Reviews
 *   description: Review management
 */

/**
 * @swagger
 * /reviews:
 *   get:
 *     tags: [Reviews]
 *     summary: List reviews (public)
 *     security: []
 *     parameters:
 *       - in: query
 *         name: review_type
 *         schema: { type: string, enum: [ground, sport, coach, application] }
 *       - in: query
 *         name: ground_id
 *         schema: { type: integer }
 *       - in: query
 *         name: sport_id
 *         schema: { type: integer }
 *       - in: query
 *         name: coach_id
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Reviews list }
 */
router.get('/', ctrl.list);

/**
 * @swagger
 * /reviews/{id}:
 *   get:
 *     tags: [Reviews]
 *     summary: Get review by ID (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Review detail }
 *       404: { description: Not found }
 */
router.get('/:id', ctrl.show);

/**
 * @swagger
 * /reviews:
 *   post:
 *     tags: [Reviews]
 *     summary: Create a review (user — requires completed booking for ground/sport)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [review_type, rating]
 *             properties:
 *               review_type:    { type: string, enum: [ground, sport, coach, application] }
 *               rating:         { type: integer, minimum: 1, maximum: 5 }
 *               comment:        { type: string }
 *               ground_id:      { type: integer }
 *               ground_sport_id:{ type: integer }
 *               coach_id:       { type: integer }
 *               booking_id:     { type: integer }
 *     responses:
 *       201: { description: Review created }
 */
router.post('/', verifyToken, requireRole('user'), createReview, validate, ctrl.create);

/**
 * @swagger
 * /reviews/{id}:
 *   put:
 *     tags: [Reviews]
 *     summary: Update a review (owner | admin)
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
 *               rating:  { type: integer, minimum: 1, maximum: 5 }
 *               comment: { type: string }
 *     responses:
 *       200: { description: Updated }
 *       403: { description: Not authorized }
 *       404: { description: Not found }
 */
router.put('/:id', verifyToken, requireRole('user', 'admin'), updateReview, validate, ctrl.update);

/**
 * @swagger
 * /reviews/{id}:
 *   delete:
 *     tags: [Reviews]
 *     summary: Delete a review (owner | admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 *       403: { description: Not authorized }
 */
router.delete('/:id', verifyToken, requireRole('user', 'admin'), ctrl.destroy);

module.exports = router;
