const router = require('express').Router();
const ctrl = require('../controllers/booking.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { createBooking, cancelBooking } = require('../validators/booking.validator');

/**
 * @swagger
 * tags:
 *   name: Bookings
 *   description: Booking management
 */

/**
 * @swagger
 * /bookings:
 *   get:
 *     tags: [Bookings]
 *     summary: List bookings (admin=all, owner=their grounds, user=own)
 *     responses:
 *       200: { description: List of bookings }
 */
router.get('/', verifyToken, requireRole('admin', 'ground_owner', 'user'), ctrl.list);

/**
 * @swagger
 * /bookings/{id}:
 *   get:
 *     tags: [Bookings]
 *     summary: Get booking by ID
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Booking detail }
 *       404: { description: Not found }
 */
router.get('/:id', verifyToken, requireRole('admin', 'ground_owner', 'user'), ctrl.show);

/**
 * @swagger
 * /bookings:
 *   post:
 *     tags: [Bookings]
 *     summary: Create a booking (user)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [ground_sport_id, slot_date, slot_ids]
 *             properties:
 *               ground_sport_id: { type: integer }
 *               slot_date:       { type: string, format: date }
 *               slot_ids:
 *                 type: array
 *                 items: { type: integer }
 *               is_game:         { type: boolean }
 *     responses:
 *       201: { description: Booking created }
 *       400: { description: Slots unavailable or validation error }
 */
router.post('/', verifyToken, requireRole('user'), createBooking, validate, ctrl.create);

/**
 * @swagger
 * /bookings/{id}/cancel:
 *   patch:
 *     tags: [Bookings]
 *     summary: Cancel a booking (user — own | admin)
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
 *               cancellation_reason: { type: string }
 *     responses:
 *       200: { description: Cancelled }
 */
router.patch('/:id/cancel', verifyToken, requireRole('user', 'admin'), cancelBooking, validate, ctrl.cancel);

/**
 * @swagger
 * /bookings/{id}:
 *   put:
 *     tags: [Bookings]
 *     summary: Update a booking (admin)
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
 *               status:               { type: string, enum: [pending, confirmed, cancelled, completed] }
 *               cancellation_reason:  { type: string }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 */
router.put('/:id', verifyToken, requireRole('admin'), ctrl.update);

/**
 * @swagger
 * /bookings/{id}:
 *   delete:
 *     tags: [Bookings]
 *     summary: Delete a booking record (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 *       404: { description: Not found }
 */
router.delete('/:id', verifyToken, requireRole('admin'), ctrl.destroy);

module.exports = router;
