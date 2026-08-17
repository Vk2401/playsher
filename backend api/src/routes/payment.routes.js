const router = require('express').Router();
const ctrl = require('../controllers/payment.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const { body } = require('express-validator');
const validate = require('../middleware/validate');

/**
 * @swagger
 * tags:
 *   name: Payments
 *   description: Payment management
 */

/**
 * @swagger
 * /payments:
 *   get:
 *     tags: [Payments]
 *     summary: List all payments (admin)
 *     responses:
 *       200: { description: Payments list }
 */
router.get('/', verifyToken, requireRole('admin'), ctrl.list);

/**
 * @swagger
 * /payments/{id}:
 *   get:
 *     tags: [Payments]
 *     summary: Get payment by ID (admin | owner user)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Payment }
 */
router.get('/:id', verifyToken, requireRole('admin', 'user'), ctrl.show);

/**
 * @swagger
 * /payments:
 *   post:
 *     tags: [Payments]
 *     summary: Create a payment for a booking (user)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [booking_id, payment_method, amount]
 *             properties:
 *               booking_id:      { type: integer }
 *               payment_method:  { type: string }
 *               payment_mode:    { type: string, enum: [online, offline] }
 *               transaction_id:  { type: string }
 *               amount:          { type: number }
 *     responses:
 *       201: { description: Payment created }
 */
router.post(
  '/',
  verifyToken,
  requireRole('user'),
  [
    body('booking_id').isInt({ min: 1 }),
    body('payment_method').notEmpty(),
    body('amount').isFloat({ min: 0 }),
  ],
  validate,
  ctrl.create
);

/**
 * @swagger
 * /payments/razorpay/create-order:
 *   post:
 *     tags: [Payments]
 *     summary: Create a Razorpay order for a booking (user)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [booking_id]
 *             properties:
 *               booking_id: { type: integer }
 *     responses:
 *       200: { description: Razorpay order created }
 */
router.post(
  '/razorpay/create-order',
  verifyToken,
  requireRole('user'),
  [body('booking_id').isInt({ min: 1 })],
  validate,
  ctrl.createRazorpayOrder
);

/**
 * @swagger
 * /payments/razorpay/verify:
 *   post:
 *     tags: [Payments]
 *     summary: Verify Razorpay payment signature (user)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [razorpay_order_id, razorpay_payment_id, razorpay_signature]
 *             properties:
 *               razorpay_order_id:   { type: string }
 *               razorpay_payment_id: { type: string }
 *               razorpay_signature:  { type: string }
 *     responses:
 *       200: { description: Payment verified }
 */
router.post(
  '/razorpay/verify',
  verifyToken,
  requireRole('user'),
  [
    body('razorpay_order_id').notEmpty(),
    body('razorpay_payment_id').notEmpty(),
    body('razorpay_signature').notEmpty(),
  ],
  validate,
  ctrl.verifyRazorpayPayment
);

/**
 * @swagger
 * /payments/{id}/status:
 *   patch:
 *     tags: [Payments]
 *     summary: Update payment status (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [payment_status]
 *             properties:
 *               payment_status: { type: string, enum: [pending, success, failed, refunded] }
 *     responses:
 *       200: { description: Status updated }
 */
router.patch(
  '/:id/status',
  verifyToken,
  requireRole('admin'),
  [body('payment_status').isIn(['pending', 'success', 'failed', 'refunded'])],
  validate,
  ctrl.updateStatus
);

module.exports = router;
