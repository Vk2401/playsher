/**
 * The public coach directory.
 *
 * Everything here is readable without a token. Only approved, active coaches
 * are listed, and each one is returned with the grounds whose owners have
 * agreed to host them — a coach's ground list is the set of places a customer
 * may actually pick when booking, so it is built from approved links only.
 */
const { Op, fn, col } = require('sequelize');
const {
  Coach, CoachGround, CoachBooking, CoachBookingSlot, Ground, GroundImage,
  Sport, Review, User,
} = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { ensureCoachSlotsForDate } = require('../utils/coachSlotGenerator');
const { appToday } = require('../utils/appTime');

/** The grounds a coach may actually be booked at. */
const APPROVED_GROUNDS_INCLUDE = {
  model     : CoachGround,
  as        : 'groundLinks',
  required  : false,
  where     : { status: 'approved' },
  attributes: ['id', 'ground_id', 'status'],
  include   : [{
    model     : Ground,
    as        : 'ground',
    attributes: ['id', 'name', 'address', 'area', 'city', 'latitude', 'longitude'],
    include   : [{ model: GroundImage, as: 'images', attributes: ['id', 'image', 'is_primary'] }],
  }],
};

/**
 * Average rating and review count for a set of coaches, in one query.
 *
 * Read separately rather than as an aggregate include because a `hasMany` join
 * plus `findAndCountAll` multiplies the row count by the number of reviews,
 * which is how a paginated list starts reporting the wrong total.
 */
async function ratingsFor(coachIds) {
  if (coachIds.length === 0) return {};
  const rows = await Review.findAll({
    where: { coach_id: coachIds, review_type: 'coach', is_active: true },
    attributes: ['coach_id', [fn('AVG', col('rating')), 'avg'], [fn('COUNT', col('id')), 'count']],
    group: ['coach_id'],
    raw: true,
  });
  return rows.reduce((acc, r) => {
    acc[r.coach_id] = { rating: Number(Number(r.avg).toFixed(2)), review_count: Number(r.count) };
    return acc;
  }, {});
}

/** Attach rating figures to a coach row, defaulting to an honest zero. */
function withRating(coach, ratings) {
  const json = coach.toJSON();
  const r = ratings[coach.id] || { rating: 0, review_count: 0 };
  json.rating = r.rating;
  json.review_count = r.review_count;
  return json;
}

/** GET /coaches — public directory */
exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { is_active: true, is_approved: true };

    if (req.query.sport_id)   where.sport_id = req.query.sport_id;
    if (req.query.sport_name) where.sport_name = { [Op.like]: `%${req.query.sport_name}%` };
    if (req.query.city)       where.city = req.query.city;
    if (req.query.level)      where.level = req.query.level;
    if (req.query.search) {
      where[Op.or] = [
        { name      : { [Op.like]: `%${req.query.search}%` } },
        { sport_name: { [Op.like]: `%${req.query.search}%` } },
        { about     : { [Op.like]: `%${req.query.search}%` } },
      ];
    }

    const include = [
      { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] },
      APPROVED_GROUNDS_INCLUDE,
    ];

    // Filtering by ground turns the link into a required join: "coaches you can
    // book at this venue" is exactly the approved-link set.
    if (req.query.ground_id) {
      include[1] = {
        ...APPROVED_GROUNDS_INCLUDE,
        required: true,
        where: { status: 'approved', ground_id: req.query.ground_id },
      };
    }

    const { count, rows } = await Coach.findAndCountAll({
      where, include, limit, offset, distinct: true,
      order: [['name', 'ASC']],
    });

    const ratings = await ratingsFor(rows.map((c) => c.id));
    return success(
      res,
      'Coaches retrieved.',
      rows.map((c) => withRating(c, ratings)),
      200,
      paginationMeta(count, page, limit),
    );
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** GET /coaches/:id — public detail */
exports.show = async (req, res) => {
  try {
    const coach = await Coach.findOne({
      where: { id: req.params.id, is_active: true, is_approved: true },
      include: [
        { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] },
        APPROVED_GROUNDS_INCLUDE,
        {
          model     : Review,
          as        : 'reviews',
          required  : false,
          where     : { review_type: 'coach', is_active: true },
          attributes: ['id', 'rating', 'comment', 'created_at'],
          include   : [{ model: User, as: 'reviewer', attributes: ['id', 'name', 'profile_picture'] }],
        },
      ],
      order: [[{ model: Review, as: 'reviews' }, 'created_at', 'DESC']],
    });
    if (!coach) return error(res, 'Coach not found.', 404);

    const ratings = await ratingsFor([coach.id]);
    return success(res, 'Coach retrieved.', withRating(coach, ratings));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * GET /coaches/:id/slots?date=YYYY-MM-DD
 *
 * What a customer may still book. A block that somebody else is holding, or
 * that the coach has blocked out, is simply absent — offering it and failing
 * on tap is the behaviour this replaces.
 */
exports.slots = async (req, res) => {
  try {
    const coach = await Coach.findOne({
      where: { id: req.params.id, is_active: true, is_approved: true },
    });
    if (!coach) return error(res, 'Coach not found.', 404);

    const date = req.query.date || appToday();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return error(res, 'date must be YYYY-MM-DD.');

    const slots = await ensureCoachSlotsForDate(coach.id, date);
    const held = new Set(
      (await CoachBookingSlot.findAll({
        where: { coach_slot_id: slots.map((s) => s.id) },
        attributes: ['coach_slot_id'],
        raw: true,
      })).map((r) => r.coach_slot_id),
    );

    return success(res, 'Slots retrieved.', slots.map((s) => ({
      id             : s.id,
      slot_date      : s.slot_date,
      slot_start_time: s.slot_start_time,
      slot_end_time  : s.slot_end_time,
      is_available   : s.is_available && !held.has(s.id),
    })));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** GET /coaches/:id/grounds — where this coach may be booked */
exports.grounds = async (req, res) => {
  try {
    const links = await CoachGround.findAll({
      where  : { coach_id: req.params.id, status: 'approved' },
      include: [{
        model     : Ground,
        as        : 'ground',
        where     : { deleted_at: null, is_active: true },
        attributes: ['id', 'name', 'address', 'area', 'city', 'latitude', 'longitude', 'price_per_slot'],
        include   : [{ model: GroundImage, as: 'images', attributes: ['id', 'image', 'is_primary'] }],
      }],
      order: [['responded_at', 'DESC']],
    });
    return success(res, 'Coach grounds retrieved.', links.map((l) => l.ground).filter(Boolean));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// ── Admin-facing CRUD, kept here for /coaches (admin-only routes) ─────────────

exports.create = async (req, res) => {
  try {
    const coach = await Coach.create(req.body);
    return success(res, 'Coach created.', coach, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    await coach.update(req.body);
    return success(res, 'Coach updated.', coach);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    const sessions = await CoachBooking.count({ where: { coach_id: coach.id } });
    if (sessions > 0) {
      // Deleting the row would cascade the sessions away with it, taking the
      // customers' history and the money trail. Deactivating keeps both.
      return error(res, 'This coach has sessions on record. Deactivate the account instead.', 409);
    }
    await coach.destroy();
    return success(res, 'Coach deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.approve = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    await coach.update({ is_approved: true, rejection_reason: null });
    return success(res, 'Coach approved.', coach);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
