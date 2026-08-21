const { Op } = require('sequelize');
const { Review, User, Coach, Booking, GroundSport } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { completeFinishedBookings } = require('../utils/bookingCompletion');

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

// A venue review is either type: both are earned by playing at the ground.
const VENUE_TYPES = ['ground', 'sport'];

/**
 * Has this user actually played at this ground?
 *
 * Only someone who booked and turned up may review a venue, so the check runs
 * off a booking that has *finished* — not merely one that exists. Past
 * bookings are retired to `completed` first, or a game played yesterday would
 * still read as upcoming and its player would be refused.
 *
 * Resolves the ground through GroundSport because a booking references a
 * ground *sport*, not the ground directly.
 *
 * @returns {Promise<object|null>} the qualifying booking, or null
 */
async function findQualifyingBooking(userId, groundId) {
  await completeFinishedBookings({ Booking }, { userId });

  return Booking.findOne({
    where  : { user_id: userId, status: 'completed', is_canceled: false },
    include: [{
      model   : GroundSport,
      as      : 'groundSport',
      required: true,
      where   : { ground_id: groundId },
    }],
    order: [['slot_date', 'DESC']],
  });
}

/**
 * The review this user has already left for this ground, if any.
 *
 * One venue review per customer per ground. Shared by `eligibility` and
 * `create` so the two can never disagree — the app must not be offered a form
 * that the POST then rejects.
 *
 * @returns {Promise<object|null>}
 */
function findExistingVenueReview(userId, groundId) {
  return Review.findOne({
    where: {
      reviewed_by_user_id: userId,
      ground_id          : groundId,
      review_type        : { [Op.in]: VENUE_TYPES },
    },
  });
}

// GET /reviews/eligibility?ground_id=
// Lets the app decide whether to offer the review form at all, rather than
// letting someone write one and only then be told they cannot post it.
exports.eligibility = async (req, res) => {
  try {
    const groundId = Number(req.query.ground_id);

    const existing = await findExistingVenueReview(req.user.id, groundId);
    if (existing) {
      return success(res, 'Eligibility checked.', {
        can_review: false,
        reason    : 'already_reviewed',
        message   : 'You have already reviewed this ground.',
        review    : existing,
      });
    }

    const booking = await findQualifyingBooking(req.user.id, groundId);
    if (!booking) {
      return success(res, 'Eligibility checked.', {
        can_review: false,
        reason    : 'no_completed_booking',
        message   : 'Only players who have booked and played here can leave a review.',
      });
    }

    return success(res, 'Eligibility checked.', {
      can_review: true,
      booking_id: booking.id,
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// POST /reviews
// A venue review is earned, not asked for. The qualifying booking is resolved
// server-side from the ground; it is never read off the request, because a
// client-supplied booking_id is exactly what let the gate be skipped.
exports.create = async (req, res) => {
  try {
    const { review_type, rating, comment, ground_id, ground_sport_id, coach_id } = req.body;

    const patch = {
      reviewed_by_user_id: req.user.id,
      review_type,
      rating,
      comment            : comment || null,
    };

    if (VENUE_TYPES.includes(review_type)) {
      if (!ground_id) return error(res, 'ground_id is required for this review type.');

      // Same two checks as `eligibility`, in the same order, so the form the app
      // is offered and the POST that accepts it can never disagree. Both run off
      // the shared helpers rather than a second copy of the query.
      const duplicate = await findExistingVenueReview(req.user.id, ground_id);
      if (duplicate) return error(res, 'You have already reviewed this ground.', 409);

      // The original check ran only `if (req.body.booking_id)`, so simply
      // omitting that field skipped it entirely and anyone could review any
      // ground. The qualifying booking is looked up from the ground instead,
      // and is never taken from the body.
      const booking = await findQualifyingBooking(req.user.id, ground_id);
      if (!booking) {
        return error(res, 'Only players who have booked and played here can leave a review.', 403);
      }

      // The booking's own sport is the trustworthy answer. A client-supplied
      // ground_sport_id is honoured only when it belongs to this ground, so a
      // review cannot be filed against another venue's sport.
      let sportId = booking.ground_sport_id;
      if (ground_sport_id && ground_sport_id !== sportId) {
        const sport = await GroundSport.findOne({
          where: { id: ground_sport_id, ground_id },
        });
        if (!sport) return error(res, 'That sport does not belong to this ground.');
        sportId = sport.id;
      }

      patch.ground_id       = ground_id;
      patch.ground_sport_id = sportId;
      patch.booking_id      = booking.id;
    } else if (review_type === 'coach') {
      if (!coach_id) return error(res, 'coach_id is required for a coach review.');
      const coach = await Coach.findByPk(coach_id);
      if (!coach) return error(res, 'Coach not found.', 404);
      patch.coach_id = coach_id;
    }

    const review = await Review.create(patch);
    const withReviewer = await Review.findByPk(review.id, {
      include: [{ model: User, as: 'reviewer', attributes: ['id', 'name'] }],
    });
    return success(res, 'Review created.', withReviewer, 201);
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
    // Only the two things a reviewer actually owns. `req.body` would have let
    // them flip is_active or re-point the review at another ground.
    const { rating, comment } = req.body;
    const patch = {};
    if (rating  !== undefined) patch.rating  = rating;
    if (comment !== undefined) patch.comment = comment;
    if (Object.keys(patch).length === 0) return error(res, 'Nothing to update.');

    await review.update(patch);
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
