const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/webhook.controller');

/**
 * @swagger
 * /webhooks/razorpay:
 *   post:
 *     tags: [Webhooks]
 *     summary: Razorpay event receiver (called by Razorpay, not by a client)
 *     description: >
 *       Records what actually happened to a transfer or a linked account.
 *       Authenticated by the `x-razorpay-signature` header against
 *       RAZORPAY_WEBHOOK_SECRET — there is no bearer token, because the caller
 *       is Razorpay. Subscribe to: transfer.processed, transfer.failed,
 *       transfer.reversed, account.activated, account.suspended,
 *       account.needs_clarification.
 *     responses:
 *       200: { description: Handled, or acknowledged and ignored }
 *       401: { description: Missing or invalid signature }
 *       500: { description: Handler failed — Razorpay should retry }
 */
router.post('/razorpay', ctrl.razorpay);

module.exports = router;
