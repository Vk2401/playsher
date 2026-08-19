/**
 * Admin Panel Controllers
 * Provides admin-scoped list operations that return ALL records
 * (unlike public endpoints which filter by is_approved/is_active).
 */
const bcrypt = require('bcryptjs');
const { Op } = require('sequelize');
const {
  Ground, GroundOwner, GroundImage, GroundSport,
  Sport, Amenity, Coach, Review, User, Booking,
  Payment, Game, GameParticipant,
} = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

const SALT_ROUNDS = 12;

// ── Grounds ───────────────────────────────────────────────────────────────────

/** GET /admin/grounds — ALL grounds, all statuses */
exports.listGrounds = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { deleted_at: null };
    if (req.query.search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${req.query.search}%` } },
        { address: { [Op.like]: `%${req.query.search}%` } },
      ];
    }
    const { count, rows } = await Ground.findAndCountAll({
      where,
      include: [
        { model: GroundOwner, as: 'owner', attributes: ['id', 'name', 'email', 'mobile'] },
        { model: GroundImage, as: 'images', attributes: ['id', 'image', 'is_primary'] },
      ],
      limit, offset, distinct: true,
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Grounds retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

// ── Sports ────────────────────────────────────────────────────────────────────

/** GET /admin/sports — ALL sports including unapproved */
exports.listSports = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = {};
    if (req.query.search) where.name = { [Op.like]: `%${req.query.search}%` };
    const { count, rows } = await Sport.findAndCountAll({
      where, limit, offset, order: [['created_at', 'DESC']],
    });
    return success(res, 'Sports retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** POST /admin/sports — create (with optional image upload) */
exports.createSport = async (req, res) => {
  try {
    const image = req.file ? req.file.publicUrl : req.body.image;
    const sport = await Sport.create({ ...req.body, image });
    return success(res, 'Sport created.', sport, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** PUT /admin/sports/:id */
exports.updateSport = async (req, res) => {
  try {
    const sport = await Sport.findByPk(req.params.id);
    if (!sport) return error(res, 'Sport not found.', 404);
    const image = req.file ? req.file.publicUrl : (req.body.image || sport.image);
    await sport.update({ ...req.body, image });
    return success(res, 'Sport updated.', sport);
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /admin/sports/:id/approve */
exports.approveSport = async (req, res) => {
  try {
    const sport = await Sport.findByPk(req.params.id);
    if (!sport) return error(res, 'Sport not found.', 404);
    await sport.update({ is_approved: true });
    return success(res, 'Sport approved.', sport);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /admin/sports/:id */
exports.deleteSport = async (req, res) => {
  try {
    const sport = await Sport.findByPk(req.params.id);
    if (!sport) return error(res, 'Sport not found.', 404);
    await sport.destroy();
    return success(res, 'Sport deleted.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Amenities ─────────────────────────────────────────────────────────────────

/** GET /admin/amenities — ALL amenities */
exports.listAmenities = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = {};
    if (req.query.type) where.type = req.query.type;
    if (req.query.search) where.name = { [Op.like]: `%${req.query.search}%` };
    const { count, rows } = await Amenity.findAndCountAll({ where, limit, offset });
    return success(res, 'Amenities retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** POST /admin/amenities — create (with optional icon upload) */
exports.createAmenity = async (req, res) => {
  try {
    const icon = req.file ? req.file.publicUrl : req.body.icon;
    const amenity = await Amenity.create({
      name: req.body.name,
      type: req.body.type,
      icon,
      is_active: req.body.is_active !== 'false',
    });
    return success(res, 'Amenity created.', amenity, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** PUT /admin/amenities/:id */
exports.updateAmenity = async (req, res) => {
  try {
    const amenity = await Amenity.findByPk(req.params.id);
    if (!amenity) return error(res, 'Amenity not found.', 404);
    const icon = req.file ? req.file.publicUrl : (req.body.icon || amenity.icon);
    await amenity.update({ ...req.body, icon });
    return success(res, 'Amenity updated.', amenity);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /admin/amenities/:id */
exports.deleteAmenity = async (req, res) => {
  try {
    const amenity = await Amenity.findByPk(req.params.id);
    if (!amenity) return error(res, 'Amenity not found.', 404);
    await amenity.destroy();
    return success(res, 'Amenity deleted.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Coaches ───────────────────────────────────────────────────────────────────

/** GET /admin/coaches — ALL coaches including unapproved */
exports.listCoaches = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = {};
    if (req.query.search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${req.query.search}%` } },
        { email: { [Op.like]: `%${req.query.search}%` } },
      ];
    }
    const { count, rows } = await Coach.findAndCountAll({ where, limit, offset, order: [['created_at', 'DESC']] });
    return success(res, 'Coaches retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /admin/coaches/:id */
exports.getCoach = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    return success(res, 'Coach retrieved.', coach);
  } catch (err) { return error(res, err.message, 500); }
};

/** POST /admin/coaches — create (with optional profile_image upload) */
exports.createCoach = async (req, res) => {
  try {
    const profile_picture = req.file ? req.file.publicUrl : req.body.profile_picture;
    const coach = await Coach.create({ ...req.body, profile_picture });
    return success(res, 'Coach created.', coach, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** PUT /admin/coaches/:id */
exports.updateCoach = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    const profile_picture = req.file
      ? req.file.publicUrl
      : (req.body.profile_picture || coach.profile_picture);
    await coach.update({ ...req.body, profile_picture });
    return success(res, 'Coach updated.', coach);
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /admin/coaches/:id/approve */
exports.approveCoach = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    await coach.update({ is_approved: true });
    return success(res, 'Coach approved.', coach);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /admin/coaches/:id */
exports.deleteCoach = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.params.id);
    if (!coach) return error(res, 'Coach not found.', 404);
    await coach.destroy();
    return success(res, 'Coach deleted.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Reviews ───────────────────────────────────────────────────────────────────

/** GET /admin/reviews — ALL reviews */
exports.listReviews = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = {};
    if (req.query.rating) where.rating = req.query.rating;
    const { count, rows } = await Review.findAndCountAll({
      where,
      include: [
        { model: User, as: 'reviewer', attributes: ['id', 'name', 'email'] },
        { model: Ground, as: 'ground', attributes: ['id', 'name'], required: false },
      ],
      limit, offset,
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Reviews retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /admin/reviews/:id */
exports.getReview = async (req, res) => {
  try {
    const review = await Review.findByPk(req.params.id, {
      include: [{ model: User, as: 'reviewer', attributes: ['id', 'name', 'email'] }],
    });
    if (!review) return error(res, 'Review not found.', 404);
    return success(res, 'Review retrieved.', review);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /admin/reviews/:id */
exports.deleteReview = async (req, res) => {
  try {
    const review = await Review.findByPk(req.params.id);
    if (!review) return error(res, 'Review not found.', 404);
    await review.destroy();
    return success(res, 'Review deleted.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Games ─────────────────────────────────────────────────────────────────────

/** GET /admin/games — ALL games */
exports.listGames = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const { count, rows } = await Game.findAndCountAll({
      include: [
        { model: User, as: 'hostedByUser', attributes: ['id', 'name'], required: false },
        { model: GameParticipant, as: 'participants', attributes: ['id', 'status'] },
      ],
      limit, offset, distinct: true,
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Games retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /admin/games/:id */
exports.getGame = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id, {
      include: [
        { model: User, as: 'hostedByUser', attributes: ['id', 'name'] },
        { model: GameParticipant, as: 'participants' },
      ],
    });
    if (!game) return error(res, 'Game not found.', 404);
    return success(res, 'Game retrieved.', game);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /admin/games/:id */
exports.deleteGame = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id);
    if (!game) return error(res, 'Game not found.', 404);
    await game.destroy();
    return success(res, 'Game deleted.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Payments ──────────────────────────────────────────────────────────────────

/** PATCH /admin/payments/:id/status — accepts {status} or {payment_status} + optional vendor_payout_status */
exports.updatePaymentStatus = async (req, res) => {
  try {
    const payment = await Payment.findByPk(req.params.id);
    if (!payment) return error(res, 'Payment not found.', 404);

    const updateData = {};

    // Handle payment_status
    const payment_status = req.body.payment_status || req.body.status;
    if (payment_status) {
      const valid = ['pending', 'success', 'failed', 'refunded'];
      if (!valid.includes(payment_status)) return error(res, `Invalid status. Must be one of: ${valid.join(', ')}`);
      updateData.payment_status = payment_status;
    }

    // Handle vendor_payout_status (for settlements)
    if (req.body.vendor_payout_status) {
      const validPayout = ['pending', 'transferred', 'no_bank_details', 'no_vendor'];
      if (!validPayout.includes(req.body.vendor_payout_status)) {
        return error(res, `Invalid vendor_payout_status. Must be one of: ${validPayout.join(', ')}`);
      }
      updateData.vendor_payout_status = req.body.vendor_payout_status;
      if (req.body.transfer_id) updateData.transfer_id = req.body.transfer_id;
    }

    if (!Object.keys(updateData).length) return error(res, 'No valid fields to update.');
    await payment.update(updateData);
    return success(res, 'Payment status updated.', payment);
  } catch (err) { return error(res, err.message, 500); }
};

// ── Bookings ──────────────────────────────────────────────────────────────────

/** PATCH /admin/bookings/:id/cancel — accepts {reason} or {cancellation_reason} */
exports.cancelBooking = async (req, res) => {
  try {
    const booking = await Booking.findByPk(req.params.id);
    if (!booking) return error(res, 'Booking not found.', 404);
    if (booking.status === 'cancelled') return error(res, 'Booking already cancelled.');
    const reason = req.body.reason || req.body.cancellation_reason || 'Cancelled by admin';
    await booking.update({ status: 'cancelled', is_canceled: true, cancellation_reason: reason });
    return success(res, 'Booking cancelled.', booking);
  } catch (err) { return error(res, err.message, 500); }
};

// ── Admin-created Users / Ground Owners ──────────────────────────────────────

/** POST /admin/users — admin creates a user directly (pre-approved, active) */
exports.createUser = async (req, res) => {
  try {
    const { name, email, mobile, password } = req.body;
    if (!name || !mobile || !password) {
      return error(res, 'name, mobile and password are required.', 422);
    }
    const exists = await User.findOne({
      where: { [Op.or]: [{ mobile }, ...(email ? [{ email }] : [])] },
    });
    if (exists) return error(res, 'Mobile or email already registered.');
    const password_hash = await bcrypt.hash(password, SALT_ROUNDS);
    const user = await User.create({
      name, email: email || null, mobile, password_hash,
      is_active: true, deleted_at: null,
    });
    return success(res, 'User created.', {
      id: user.id, name: user.name, email: user.email,
      mobile: user.mobile, is_active: user.is_active,
    }, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** POST /admin/ground-owners — admin creates a ground owner (pre-approved, active) */
exports.createGroundOwner = async (req, res) => {
  try {
    const { name, email, mobile, password } = req.body;
    if (!name || !email || !mobile || !password) {
      return error(res, 'name, email, mobile and password are required.', 422);
    }
    const exists = await GroundOwner.findOne({
      where: { [Op.or]: [{ email }, { mobile }] },
    });
    if (exists) return error(res, 'Email or mobile already registered.');
    const password_hash = await bcrypt.hash(password, SALT_ROUNDS);
    const owner = await GroundOwner.create({
      name, email, mobile, password_hash,
      is_approved: true, is_active: true,
    });
    return success(res, 'Ground owner created.', {
      id: owner.id, name: owner.name, email: owner.email,
      mobile: owner.mobile, is_approved: owner.is_approved, is_active: owner.is_active,
    }, 201);
  } catch (err) { return error(res, err.message, 500); }
};

// ── Vendor Settlements ─────────────────────────────────────────────────────

/** GET /admin/vendors — list ground owners with booking/revenue stats for settlements */
exports.listVendors = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = {};
    if (req.query.search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${req.query.search}%` } },
        { email: { [Op.like]: `%${req.query.search}%` } },
        { mobile: { [Op.like]: `%${req.query.search}%` } },
      ];
    }
    const { count, rows } = await GroundOwner.findAndCountAll({
      where,
      attributes: { exclude: ['password_hash'] },
      include: [
        { model: Ground, as: 'grounds', attributes: ['id', 'name'] },
      ],
      limit, offset, distinct: true,
      order: [['created_at', 'DESC']],
    });

    // Enrich with payment stats
    const vendors = await Promise.all(rows.map(async (owner) => {
      const groundIds = owner.grounds.map(g => g.id);
      let totalEarned = 0;
      let totalBookings = 0;
      if (groundIds.length) {
        const bookings = await Booking.findAll({
          where: { status: { [Op.in]: ['confirmed', 'completed'] } },
          include: [{
            model: GroundSport, as: 'groundSport', attributes: [],
            where: { ground_id: groundIds },
          }, {
            model: Payment, as: 'payment', attributes: ['amount', 'payment_status', 'vendor_payout_status'],
            where: { payment_status: 'success' },
            required: false,
          }],
          attributes: ['id'],
          raw: false,
        });
        totalBookings = bookings.length;
        totalEarned = bookings.reduce((sum, b) => sum + (parseFloat(b.payment?.amount) || 0), 0);
      }
      const plain = owner.toJSON();
      plain.total_earned = totalEarned;
      plain.total_bookings = totalBookings;
      plain.ground_count = groundIds.length;
      return plain;
    }));

    return success(res, 'Vendors retrieved.', vendors, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /admin/vendors/:id/bookings — bookings for a vendor's grounds */
exports.getVendorBookings = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const owner = await GroundOwner.findByPk(req.params.id, {
      include: [{ model: Ground, as: 'grounds', attributes: ['id'] }],
    });
    if (!owner) return error(res, 'Vendor not found.', 404);

    const groundIds = owner.grounds.map(g => g.id);
    if (!groundIds.length) {
      return success(res, 'No grounds found.', [], 200, paginationMeta(0, page, limit));
    }

    const { count, rows } = await Booking.findAndCountAll({
      include: [
        {
          model: GroundSport, as: 'groundSport',
          where: { ground_id: groundIds },
          include: [
            { model: Ground, as: 'ground', attributes: ['id', 'name'] },
            { model: Sport, as: 'sport', attributes: ['id', 'name'] },
          ],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'mobile', 'email'] },
        { model: Payment, as: 'payment' },
      ],
      limit, offset, distinct: true,
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Vendor bookings retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /admin/vendors/:id/stats — vendor statistics */
exports.getVendorStats = async (req, res) => {
  try {
    const owner = await GroundOwner.findByPk(req.params.id, {
      attributes: { exclude: ['password_hash'] },
      include: [{ model: Ground, as: 'grounds', attributes: ['id', 'name', 'is_active'] }],
    });
    if (!owner) return error(res, 'Vendor not found.', 404);

    const groundIds = owner.grounds.map(g => g.id);
    const activeGrounds = owner.grounds.filter(g => g.is_active).length;

    let totalBookings = 0;
    let totalRevenue = 0;
    if (groundIds.length) {
      totalBookings = await Booking.count({
        include: [{
          model: GroundSport, as: 'groundSport', attributes: [],
          where: { ground_id: groundIds },
        }],
      });
      const payments = await Payment.findAll({
        where: { payment_status: 'success' },
        include: [{
          model: Booking, as: 'bookingRecord', attributes: [],
          include: [{
            model: GroundSport, as: 'groundSport', attributes: [],
            where: { ground_id: groundIds },
          }],
        }],
        attributes: ['amount'],
        raw: true,
      });
      totalRevenue = payments.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
    }

    return success(res, 'Vendor stats retrieved.', {
      ...owner.toJSON(),
      stats: {
        total_grounds: groundIds.length,
        active_grounds: activeGrounds,
        total_bookings: totalBookings,
        total_revenue: totalRevenue,
      },
    });
  } catch (err) { return error(res, err.message, 500); }
};
