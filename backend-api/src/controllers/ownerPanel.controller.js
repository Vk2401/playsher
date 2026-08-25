/**
 * Ground Owner Panel Controllers
 * Provides owner-scoped operations filtered by req.user.id.
 */
const { Op, literal } = require('sequelize');
const {
  Ground, GroundOwner, GroundImage, GroundSport, GroundAmenity,
  Sport, Amenity, Slot, Booking, BookedSlot, User, Game, GameParticipant, Payment,
  Coach, CoachGround, CoachBooking,
} = require('../models');
const { success, error } = require('../utils/response');
const { pickGroundFields } = require('../utils/groundFields');
const { ensureSlotsForDate } = require('../utils/slotGenerator');
const { releaseExpiredHolds } = require('../utils/slotHolds');
const { completeFinishedBookings } = require('../utils/bookingCompletion');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { notify } = require('../utils/notify');
const { appToday } = require('../utils/appTime');

// ── Grounds ───────────────────────────────────────────────────────────────────

/** GET /ground-owner/grounds */
exports.listGrounds = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { owner_id: req.user.id, deleted_at: null };
    if (req.query.search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${req.query.search}%` } },
        { address: { [Op.like]: `%${req.query.search}%` } },
      ];
    }
    const { count, rows } = await Ground.findAndCountAll({
      where,
      include: [
        { model: GroundImage, as: 'images', attributes: ['id', 'image', 'is_primary'] },
        { model: Amenity, as: 'amenities', through: { attributes: [] }, attributes: ['id', 'name', 'icon', 'type'] },
      ],
      limit, offset, distinct: true,
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Grounds retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /ground-owner/grounds/:id */
exports.getGround = async (req, res) => {
  try {
    const ground = await Ground.findOne({
      where: { id: req.params.id, owner_id: req.user.id, deleted_at: null },
      include: [
        { model: GroundImage, as: 'images' },
        { model: Amenity, as: 'amenities', through: { attributes: [] } },
        {
          model: GroundSport, as: 'groundSports',
          include: [{ model: Sport, as: 'sport' }],
        },
      ],
    });
    if (!ground) return error(res, 'Ground not found.', 404);
    return success(res, 'Ground retrieved.', ground);
  } catch (err) { return error(res, err.message, 500); }
};

/** POST /ground-owner/grounds (with optional main_image upload) */
exports.createGround = async (req, res) => {
  try {
    const ground = await Ground.create({
      ...pickGroundFields(req.body),
      owner_id: req.user.id,
    });
    if (req.file) {
      await GroundImage.create({
        ground_id: ground.id,
        image: req.file.publicUrl,
        is_primary: true,
      });
    }
    return success(res, 'Ground created.', ground, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** PUT /ground-owner/grounds/:id */
exports.updateGround = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const patch = pickGroundFields(req.body);
    if (Object.keys(patch).length === 0) {
      return error(res, 'No updatable fields supplied.');
    }
    await ground.update(patch);
    return success(res, 'Ground updated.', ground);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /ground-owner/grounds/:id */
exports.deleteGround = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    await ground.update({ deleted_at: new Date() });
    return success(res, 'Ground deleted.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Ground Images ─────────────────────────────────────────────────────────────

/** POST /ground-owner/grounds/:id/images (multipart OR JSON) */
exports.addImage = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    let imagePath;
    if (req.file) {
      imagePath = req.file.publicUrl;
    } else if (req.body.image) {
      imagePath = req.body.image;
    } else {
      return error(res, 'Image file or URL required.');
    }

    const is_primary = req.body.is_primary === 'true' || req.body.is_primary === true;
    if (is_primary) {
      await GroundImage.update({ is_primary: false }, { where: { ground_id: ground.id } });
    }

    const img = await GroundImage.create({ ground_id: ground.id, image: imagePath, is_primary });
    return success(res, 'Image added.', img, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /ground-owner/grounds/:id/images/:imageId */
exports.deleteImage = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    const img = await GroundImage.findOne({ where: { id: req.params.imageId, ground_id: ground.id } });
    if (!img) return error(res, 'Image not found.', 404);
    await img.destroy();
    return success(res, 'Image deleted.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Ground Amenities ──────────────────────────────────────────────────────────

/** POST /ground-owner/grounds/:id/amenities — body: {amenity_id} or {amenity_ids:[]} */
exports.addAmenity = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const ids = req.body.amenity_ids
      ? (Array.isArray(req.body.amenity_ids) ? req.body.amenity_ids : [req.body.amenity_ids])
      : req.body.amenity_id ? [req.body.amenity_id] : [];

    if (!ids.length) return error(res, 'amenity_id or amenity_ids required.');
    const records = ids.map((aid) => ({ ground_id: ground.id, amenity_id: Number(aid) }));
    await GroundAmenity.bulkCreate(records, { ignoreDuplicates: true });
    return success(res, 'Amenity added.');
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /ground-owner/grounds/:id/amenities/:amenityId */
exports.removeAmenity = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    const deleted = await GroundAmenity.destroy({ where: { ground_id: ground.id, amenity_id: req.params.amenityId } });
    if (!deleted) return error(res, 'Association not found.', 404);
    return success(res, 'Amenity removed.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Ground Sports ─────────────────────────────────────────────────────────────

/** POST /ground-owner/grounds/:id/sports — body: {sport_id, min_slots?, max_slots?} */
exports.addSport = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const {
      sport_id,
      min_slots = 1,
      max_slots = 8,
      player_counts = '2',
      cancellation_policy = 'No refund',
    } = req.body;

    if (!sport_id) return error(res, 'sport_id required.');
    const exists = await GroundSport.findOne({ where: { ground_id: ground.id, sport_id } });
    if (exists) return error(res, 'Sport already added to this ground.');

    const gs = await GroundSport.create({
      ground_id: ground.id,
      sport_id,
      min_slots,
      max_slots,
      player_counts,
      cancellation_policy,
      is_active: true,
    });
    return success(res, 'Sport added.', gs, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** PUT /ground-owner/grounds/:id/sports/:sportId — sportId is the ground_sport row id */
exports.updateSport = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const gs = await GroundSport.findOne({ where: { id: req.params.sportId, ground_id: ground.id } });
    if (!gs) return error(res, 'Ground sport not found.', 404);

    // Whitelist: sport_id and ground_id are identity, not settings. Changing
    // sport_id here would silently reassign every slot and booking already
    // attached to this row.
    // price_per_half_hour is deliberately absent. A slot costs what the
    // venue charges (grounds.price_per_slot); the old per-sport column is
    // kept for one release as a record and is read by nothing, so writing
    // to it would only create a figure that misleads whoever reads the row.
    const { min_slots, max_slots, player_counts, cancellation_policy, is_active } = req.body;
    const patch = {};
    if (min_slots           !== undefined) patch.min_slots           = min_slots;
    if (max_slots           !== undefined) patch.max_slots           = max_slots;
    if (player_counts       !== undefined) patch.player_counts       = player_counts;
    if (cancellation_policy !== undefined) patch.cancellation_policy = cancellation_policy;
    if (is_active           !== undefined) patch.is_active           = is_active;

    if (Object.keys(patch).length === 0) return error(res, 'No updatable fields supplied.');
    if (patch.min_slots !== undefined && patch.max_slots !== undefined
        && Number(patch.min_slots) > Number(patch.max_slots)) {
      return error(res, 'min_slots cannot exceed max_slots.');
    }

    await gs.update(patch);
    return success(res, 'Sport updated.', gs);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /ground-owner/grounds/:id/sports/:sportId — sportId is the ground_sport row id */
exports.removeSport = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.id, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    const gs = await GroundSport.findOne({ where: { id: req.params.sportId, ground_id: ground.id } });
    if (!gs) return error(res, 'Ground sport not found.', 404);
    await gs.destroy();
    return success(res, 'Sport removed.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Slots ─────────────────────────────────────────────────────────────────────

/** GET /ground-owner/grounds/:groundId/slots */
exports.listSlots = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.groundId, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const groundSports = await GroundSport.findAll({
      where: { ground_id: ground.id },
      include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
    });
    const gsIds = groundSports.map((gs) => gs.id);

    // Slots are generated on demand from the weekly schedule, so a future date
    // holds no rows until someone asks for it. Generate here too, otherwise the
    // owner sees an empty day while customers see a bookable one — and cannot
    // close an individual slot ahead of time.
    if (req.query.date) {
      for (const gsId of gsIds) {
        await releaseExpiredHolds(
          { Booking, BookedSlot, Slot },
          { groundSportId: gsId, slotDate: req.query.date },
        );
        await ensureSlotsForDate(gsId, req.query.date);
      }
    }

    const where = gsIds.length ? { ground_sport_id: { [Op.in]: gsIds } } : { ground_sport_id: -1 };
    if (req.query.date) where.slot_date = req.query.date;

    const slots = await Slot.findAll({
      where,
      include: [{
        model: GroundSport, as: 'groundSport',
        include: [{ model: Sport, as: 'sport', attributes: ['id', 'name'] }],
      }],
      order: [['slot_date', 'ASC'], ['slot_start_time', 'ASC']],
    });

    return success(res, 'Slots retrieved.', { slots, ground_sports: groundSports });
  } catch (err) { return error(res, err.message, 500); }
};

/** POST /ground-owner/grounds/:groundId/slots */
exports.createSlot = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.groundId, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const { ground_sport_id, slot_date, slot_start_time, slot_end_time } = req.body;
    if (!ground_sport_id || !slot_date || !slot_start_time || !slot_end_time) {
      return error(res, 'ground_sport_id, slot_date, slot_start_time, slot_end_time are required.');
    }
    const gs = await GroundSport.findOne({ where: { id: ground_sport_id, ground_id: ground.id } });
    if (!gs) return error(res, 'Ground sport not found for this ground.', 404);

    const slot = await Slot.create({ ground_sport_id, slot_date, slot_start_time, slot_end_time, is_available: true });
    return success(res, 'Slot created.', slot, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** PUT /ground-owner/grounds/:groundId/slots/:slotId */
exports.updateSlot = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.groundId, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const gsIds = (await GroundSport.findAll({ where: { ground_id: ground.id } })).map((g) => g.id);
    const slot = await Slot.findOne({ where: { id: req.params.slotId, ground_sport_id: { [Op.in]: gsIds } } });
    if (!slot) return error(res, 'Slot not found.', 404);

    await slot.update(req.body);
    return success(res, 'Slot updated.', slot);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /ground-owner/grounds/:groundId/slots/:slotId */
exports.deleteSlot = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.groundId, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const gsIds = (await GroundSport.findAll({ where: { ground_id: ground.id } })).map((g) => g.id);
    const slot = await Slot.findOne({ where: { id: req.params.slotId, ground_sport_id: { [Op.in]: gsIds } } });
    if (!slot) return error(res, 'Slot not found.', 404);

    await slot.destroy();
    return success(res, 'Slot deleted.');
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /ground-owner/grounds/:groundId/slots/:slotId/toggle */
exports.toggleSlot = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.groundId, owner_id: req.user.id, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);

    const gsIds = (await GroundSport.findAll({ where: { ground_id: ground.id } })).map((g) => g.id);
    const slot = await Slot.findOne({ where: { id: req.params.slotId, ground_sport_id: { [Op.in]: gsIds } } });
    if (!slot) return error(res, 'Slot not found.', 404);

    await slot.update({ is_available: !slot.is_available });
    return success(res, `Slot marked ${slot.is_available ? 'available' : 'unavailable'}.`, slot);
  } catch (err) { return error(res, err.message, 500); }
};

// ── Bookings ──────────────────────────────────────────────────────────────────

/** GET /ground-owner/bookings */
exports.listBookings = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    await completeFinishedBookings({ Booking });
    const { count, rows } = await Booking.findAndCountAll({
      include: [
        {
          model: GroundSport, as: 'groundSport', required: true,
          include: [{ model: Ground, as: 'ground', where: { owner_id: req.user.id }, required: true }],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'mobile', 'email'] },
        { model: Payment, as: 'paymentRecord', required: false },
      ],
      limit, offset, distinct: true,
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Bookings retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /ground-owner/bookings/:id */
exports.getBooking = async (req, res) => {
  try {
    await completeFinishedBookings({ Booking }, { bookingId: req.params.id });

    const booking = await Booking.findOne({
      where: { id: req.params.id },
      include: [
        {
          model: GroundSport, as: 'groundSport', required: true,
          include: [{ model: Ground, as: 'ground', where: { owner_id: req.user.id }, required: true }],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'mobile', 'email'] },
      ],
    });
    if (!booking) return error(res, 'Booking not found.', 404);
    return success(res, 'Booking retrieved.', booking);
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /ground-owner/bookings/:id/cancel */
exports.cancelBooking = async (req, res) => {
  try {
    const booking = await Booking.findOne({
      where: { id: req.params.id },
      include: [{
        model: GroundSport, as: 'groundSport', required: true,
        include: [{ model: Ground, as: 'ground', where: { owner_id: req.user.id }, required: true }],
      }],
    });
    if (!booking) return error(res, 'Booking not found.', 404);
    if (booking.status === 'cancelled') return error(res, 'Booking already cancelled.');
    const reason = req.body.reason || req.body.cancellation_reason || 'Cancelled by owner';
    await booking.update({ status: 'cancelled', is_canceled: true, cancellation_reason: reason });
    return success(res, 'Booking cancelled.', booking);
  } catch (err) { return error(res, err.message, 500); }
};

// ── Games ─────────────────────────────────────────────────────────────────────

/** GET /ground-owner/games */
exports.listGames = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const { count, rows } = await Game.findAndCountAll({
      where: { hosted_by_ground_owner_id: req.user.id },
      include: [{ model: GameParticipant, as: 'participants', attributes: ['id', 'status'] }],
      limit, offset, distinct: true,
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Games retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

// ── Coaches at my grounds ─────────────────────────────────────────────────────

/** The ids of the grounds this owner actually owns. Every query below is scoped to it. */
async function ownedGroundIds(ownerId) {
  const rows = await Ground.findAll({
    where: { owner_id: ownerId, deleted_at: null },
    attributes: ['id'],
    raw: true,
  });
  return rows.map((r) => r.id);
}

/** What an owner needs to see about a coach asking to work at their ground. */
const COACH_REQUEST_INCLUDES = [
  {
    model: Coach, as: 'coach',
    attributes: [
      'id', 'name', 'email', 'mobile', 'sport_name', 'level',
      'experience_years', 'about', 'profile_picture', 'price_per_slot', 'is_approved',
    ],
  },
  { model: Ground, as: 'ground', attributes: ['id', 'name', 'area', 'city'] },
];

/** GET /ground-owner/coach-requests */
exports.listCoachRequests = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const groundIds = await ownedGroundIds(req.user.id);
    if (groundIds.length === 0) {
      return success(res, 'Coach requests retrieved.', [], 200, paginationMeta(0, page, limit));
    }

    const where = { ground_id: groundIds };
    if (req.query.status) where.status = req.query.status;

    const { count, rows } = await CoachGround.findAndCountAll({
      where,
      include: COACH_REQUEST_INCLUDES,
      // Pending first: an unanswered request is the only row that needs the
      // owner to do something, and it must not sink under old decisions.
      order: [
        [literal("FIELD(`CoachGround`.`status`, 'pending', 'approved', 'rejected')"), 'ASC'],
        ['created_at', 'DESC'],
      ],
      limit, offset, distinct: true,
    });
    return success(res, 'Coach requests retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** Load one request and prove it belongs to a ground this owner owns. */
async function ownedRequest(req) {
  const link = await CoachGround.findByPk(req.params.id, { include: COACH_REQUEST_INCLUDES });
  if (!link) return { error: ['Request not found.', 404] };
  const ground = await Ground.findOne({
    where: { id: link.ground_id, owner_id: req.user.id, deleted_at: null },
  });
  // Same answer for "does not exist" and "is not yours", so this endpoint
  // cannot be used to discover which request ids exist.
  if (!ground) return { error: ['Request not found.', 404] };
  return { link, ground };
}

/** PATCH /ground-owner/coach-requests/:id/approve */
exports.approveCoachRequest = async (req, res) => {
  try {
    const { link, ground, error: notFound } = await ownedRequest(req);
    if (notFound) return error(res, notFound[0], notFound[1]);
    if (link.status === 'approved') return error(res, 'Already approved.', 409);

    await link.update({
      status       : 'approved',
      response_note: req.body.response_note || null,
      responded_at : new Date(),
    });

    await notify({
      recipientType: 'coach',
      recipientId  : link.coach_id,
      type         : 'coach_ground_approved',
      title        : 'Your ground registration was approved',
      message      : `${ground.name} has approved you to coach there. Players can now book you at this venue.`,
      referenceType: 'coach_ground',
      referenceId  : link.id,
      actionPath   : '/coach/grounds',
    });

    return success(res, 'Coach approved for this ground.', link);
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /ground-owner/coach-requests/:id/reject */
exports.rejectCoachRequest = async (req, res) => {
  try {
    const { link, ground, error: notFound } = await ownedRequest(req);
    if (notFound) return error(res, notFound[0], notFound[1]);
    if (link.status === 'rejected') return error(res, 'Already declined.', 409);

    const upcoming = await CoachBooking.count({
      where: {
        coach_id    : link.coach_id,
        ground_id   : link.ground_id,
        session_date: { [Op.gte]: appToday() },
        status      : { [Op.in]: ['pending', 'confirmed'] },
      },
    });
    if (upcoming > 0) {
      // Withdrawing the registration would hide a session that is still going
      // to happen. The owner has to deal with those first.
      return error(res, 'This coach still has upcoming sessions booked at your ground.', 409);
    }

    await link.update({
      status       : 'rejected',
      response_note: req.body.response_note || null,
      responded_at : new Date(),
    });

    await notify({
      recipientType: 'coach',
      recipientId  : link.coach_id,
      type         : 'coach_ground_rejected',
      title        : 'Your ground registration was declined',
      message      : req.body.response_note
        ? `${ground.name} declined your request: ${req.body.response_note}`
        : `${ground.name} declined your request to coach there.`,
      referenceType: 'coach_ground',
      referenceId  : link.id,
      actionPath   : '/coach/grounds',
    });

    return success(res, 'Request declined.', link);
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /ground-owner/coaches — the coaches approved to work at my grounds */
exports.listGroundCoaches = async (req, res) => {
  try {
    const groundIds = await ownedGroundIds(req.user.id);
    if (groundIds.length === 0) return success(res, 'Coaches retrieved.', []);

    const rows = await CoachGround.findAll({
      where  : { ground_id: groundIds, status: 'approved' },
      include: COACH_REQUEST_INCLUDES,
      order  : [['responded_at', 'DESC']],
    });
    return success(res, 'Coaches retrieved.', rows);
  } catch (err) { return error(res, err.message, 500); }
};

/**
 * GET /ground-owner/coach-sessions
 *
 * Coaching sessions taking place on this owner's courts. They are booked
 * between a player and a coach, but they occupy the owner's ground, so the
 * owner sees them alongside their own bookings rather than finding out on the day.
 */
exports.listCoachSessions = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const groundIds = await ownedGroundIds(req.user.id);
    if (groundIds.length === 0) {
      return success(res, 'Coaching sessions retrieved.', [], 200, paginationMeta(0, page, limit));
    }

    const where = { ground_id: groundIds };
    if (req.query.status) where.status = req.query.status;
    if (req.query.upcoming === 'true') where.session_date = { [Op.gte]: appToday() };
    if (req.query.date) where.session_date = req.query.date;

    const { count, rows } = await CoachBooking.findAndCountAll({
      where,
      include: [
        { model: Coach,  as: 'coach',  attributes: ['id', 'name', 'mobile', 'sport_name', 'profile_picture'] },
        { model: User,   as: 'user',   attributes: ['id', 'name', 'mobile'] },
        { model: Ground, as: 'ground', attributes: ['id', 'name'] },
      ],
      order: req.query.upcoming === 'true'
        ? [['session_date', 'ASC'], ['time_from', 'ASC']]
        : [['session_date', 'DESC'], ['time_from', 'DESC']],
      limit, offset, distinct: true,
    });
    return success(res, 'Coaching sessions retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};
