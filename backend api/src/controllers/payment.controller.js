const { Payment, Booking, User } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const Razorpay = require('razorpay');
const crypto = require('crypto');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const { count, rows } = await Payment.findAndCountAll({
      include: [{ model: User, as: 'paidBy', attributes: ['id', 'name', 'mobile', 'email'] }],
      limit,
      offset,
      order: [['created_at', 'DESC']],
    });
    // Normalize field names for admin UI
    const payments = rows.map((r) => {
      const p = r.toJSON();
      p.user = p.paidBy || null;
      p.status = p.payment_status || p.status || 'pending';
      p.amount = p.amount || p.total || p.price || 0;
      return p;
    });
    return success(res, 'Payments retrieved.', payments, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const payment = await Payment.findByPk(req.params.id, {
      include: [
        { model: User, as: 'paidBy', attributes: ['id', 'name', 'mobile', 'email'] },
        { model: Booking, as: 'bookingRecord' },
      ],
    });
    if (!payment) return error(res, 'Payment not found.', 404);
    if (req.user.role === 'user' && payment.done_by_user_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    return success(res, 'Payment retrieved.', payment);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.create = async (req, res) => {
  try {
    const { booking_id, payment_method, payment_mode, transaction_id, amount } = req.body;
    const booking = await Booking.findByPk(booking_id);
    if (!booking) return error(res, 'Booking not found.', 404);
    if (booking.user_id !== req.user.id) return error(res, 'Forbidden.', 403);

    const user = await User.findByPk(req.user.id, { attributes: ['name', 'mobile', 'email'] });

    const payment = await Payment.create({
      booking_id,
      done_by_user_id: req.user.id,
      payment_done_by_mobile: user.mobile,
      payment_done_by_email: user.email,
      payment_done_by_name: user.name,
      payment_status: 'pending',
      payment_method,
      payment_mode: payment_mode || 'online',
      payment_timestamp: new Date(),
      amount: amount || booking.total_amount,
      transaction_id,
    });

    await booking.update({ payment_id: payment.id, status: 'confirmed' });
    return success(res, 'Payment recorded.', payment, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.createRazorpayOrder = async (req, res) => {
  try {
    const { booking_id } = req.body;

    if (!booking_id) return error(res, 'booking_id is required.');

    const booking = await Booking.findByPk(booking_id);
    if (!booking) return error(res, 'Booking not found.', 404);
    if (booking.user_id !== req.user.id) return error(res, 'Forbidden.', 403);

    // Amount in paise (INR smallest unit)
    const amountInPaise = Math.round(parseFloat(booking.total_amount) * 100);

    const order = await razorpay.orders.create({
      amount: amountInPaise,
      currency: 'INR',
      receipt: `booking_${booking.id}`,
    });

    // Create a payment record linked to this booking
    const user = await User.findByPk(req.user.id, { attributes: ['name', 'mobile', 'email'] });
    const payment = await Payment.create({
      booking_id,
      done_by_user_id: req.user.id,
      payment_done_by_mobile: user.mobile,
      payment_done_by_email: user.email,
      payment_done_by_name: user.name,
      payment_status: 'pending',
      payment_method: 'razorpay',
      payment_mode: 'online',
      payment_timestamp: new Date(),
      amount: booking.total_amount,
      razorpay_order_id: order.id,
    });

    return success(res, 'Razorpay order created.', {
      order_id: order.id,
      amount: amountInPaise,
      currency: 'INR',
      key_id: process.env.RAZORPAY_KEY_ID,
      payment_id: payment.id,
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.verifyRazorpayPayment = async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return error(res, 'razorpay_order_id, razorpay_payment_id, and razorpay_signature are required.');
    }

    // Verify signature using HMAC SHA256
    const expectedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex');

    if (expectedSignature !== razorpay_signature) {
      return error(res, 'Payment verification failed. Invalid signature.');
    }

    // Find payment by razorpay_order_id
    const payment = await Payment.findOne({ where: { razorpay_order_id } });
    if (!payment) return error(res, 'Payment not found for this order.', 404);

    // Update payment with Razorpay details
    await payment.update({
      razorpay_payment_id,
      razorpay_signature,
      payment_status: 'success',
    });

    // Mark booking as confirmed
    const booking = await Booking.findByPk(payment.booking_id);
    if (booking) {
      await booking.update({ payment_id: payment.id, status: 'confirmed' });
    }

    return success(res, 'Payment verified successfully.', { payment, booking });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.updateStatus = async (req, res) => {
  try {
    const payment = await Payment.findByPk(req.params.id);
    if (!payment) return error(res, 'Payment not found.', 404);
    const { payment_status } = req.body;
    await payment.update({ payment_status });
    return success(res, 'Payment status updated.', payment);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
