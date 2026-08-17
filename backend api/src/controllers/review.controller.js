const { Review, User, Ground, Coach, Booking } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { is_active: true };
    if (req.query.review_type) where.review_type = req.query.review_type;
    if (req.query.ground_id) where.ground_id = req.query.ground_id;
    if (req.query.sport_id) where.ground_sport_id = req.query.sport_id;
    if (req.query.coach_id) where.coach_id = req.query.coach_id;

    const { count, rows } = await Review.findAndCountAll({
      where,
      include: [{ model: User, as: 'reviewer', attributes: ['id', 'name'] }],
      limit,
      offset,
    });
    return success(res, 'Reviews retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const review = await Review.findByPk(req.params.id, {
      include: [{ model: User, as: 'reviewer', attributes: ['id', 'name'] }],
    });
    if (!review) return error(res, 'Review not found.', 404);
    return success(res, 'Review retrieved.', review);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.create = async (req, res) => {
  try {
    // For ground/sport reviews, verify a completed booking exists
    if (['ground', 'sport'].includes(req.body.review_type) && req.body.booking_id) {
      const booking = await Booking.findOne({
        where: { id: req.body.booking_id, user_id: req.user.id, status: 'completed' },
      });
      if (!booking) return error(res, 'A completed booking is required to leave this review.');
    }
    const review = await Review.create({ ...req.body, reviewed_by_user_id: req.user.id });
    return success(res, 'Review created.', review, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const review = await Review.findByPk(req.params.id);
    if (!review) return error(res, 'Review not found.', 404);
    if (req.user.role === 'user' && review.reviewed_by_user_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    await review.update(req.body);
    return success(res, 'Review updated.', review);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const review = await Review.findByPk(req.params.id);
    if (!review) return error(res, 'Review not found.', 404);
    if (req.user.role === 'user' && review.reviewed_by_user_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    await review.destroy();
    return success(res, 'Review deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
