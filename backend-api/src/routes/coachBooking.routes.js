const router = require('express').Router();
const ctrl = require('../controllers/coachBooking.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { createCoachBooking, cancelCoachBooking } = require('../validators/coachBooking.validator');

/**
 * @swagger
 * tags:
 *   name: CoachBookings
 *   description: Coaching sessions booked by a customer
 */

const customer = [verifyToken, requireRole('user')];

/**
 * @swagger
 * /coach-bookings:
 *   post:
 *     tags: [CoachBookings]
 *     summary: Book a coaching session
 *     description: >
 *       The session is created as `pending` and its blocks are held until the
 *       coach accepts or declines it. The amount is computed on the server from
 *       the coach's `price_per_slot`; any amount sent by the client is ignored.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [coach_id, session_date, slot_ids]
 *             properties:
 *               coach_id:      { type: integer }
 *               ground_id:     { type: integer, description: Must be a ground the coach is approved at }
 *               session_date:  { type: string, format: date }
 *               slot_ids:
 *                 type: array
 *                 items: { type: integer }
 *                 description: One unbroken stretch of the coach's free blocks
 *               customer_note: { type: string }
 *     responses:
 *       201: { description: Session requested, awaiting the coach }
 *       400: { description: Invalid slots, a gap in the times, or a past slot }
 *       404: { description: Coach or ground not found }
 *       409: { description: Coach has no price, or is not registered at that ground }
 */
router.post('/', ...customer, createCoachBooking, validate, ctrl.create);

/**
 * @swagger
 * /coach-bookings:
 *   get:
 *     tags: [CoachBookings]
 *     summary: My coaching sessions
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, confirmed, rejected, cancelled, completed] }
 *     responses:
 *       200: { description: Session list }
 */
router.get('/', ...customer, ctrl.list);

/**
 * @swagger
 * /coach-bookings/upcoming:
 *   get:
 *     tags: [CoachBookings]
 *     summary: My next few sessions
 *     responses:
 *       200: { description: Up to five upcoming sessions }
 */
router.get('/upcoming', ...customer, ctrl.upcoming);

/**
 * @swagger
 * /coach-bookings/{id}:
 *   get:
 *     tags: [CoachBookings]
 *     summary: One of my sessions
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Session detail }
 *       403: { description: Not mine }
 *       404: { description: Not found }
 */
router.get('/:id', ...customer, ctrl.show);

/**
 * @swagger
 * /coach-bookings/{id}/cancel:
 *   patch:
 *     tags: [CoachBookings]
 *     summary: Cancel one of my sessions and release its time
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
 *       409: { description: Already resolved }
 */
router.patch('/:id/cancel', ...customer, cancelCoachBooking, validate, ctrl.cancel);

module.exports = router;
