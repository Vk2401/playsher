/**
 * Ground Owner Panel Controllers
 * Provides owner-scoped operations filtered by req.user.id.
 */
const { Op, literal } = require('sequelize');
const {
  sequelize,
  Ground, GroundOwner, GroundImage, GroundSport, GroundAmenity,
  Sport, Amenity, Slot, Booking, BookedSlot, User, Game, Payment,
  Coach, CoachGround, CoachBooking, BankDetails,
} = require('../models');
const { success, error } = require('../utils/response');
const { pickGroundFields } = require('../utils/groundFields');
const { ensureSlotsForDate } = require('../utils/slotGenerator');
const { releaseExpiredHolds, cancelBookingAndReleaseSlots } = require('../utils/slotHolds');
const { completeFinishedBookings } = require('../utils/bookingCompletion');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { notify } = require('../utils/notify');
const { appToday } = require('../utils/appTime');
const {
  BOOKING_INCLUDE, serialize: serializeGame, findGamesByIds,
} = require('../utils/gameView');

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

/** POST /ground-owner/grounds (with optional cover_image upload) */
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
    // A new cover photo on its own is a change, even when no text field moved.
    if (Object.keys(patch).length === 0 && !req.file) {
      return error(res, 'No updatable fields supplied.');
    }
    if (Object.keys(patch).length > 0) await ground.update(patch);

    // Replacing the cover demotes the old one rather than deleting it: the
    // photo stays in the gallery, which is where an owner expects it to go.
    if (req.file) {
      await GroundImage.update(
        { is_primary: false },
        { where: { ground_id: ground.id, is_primary: true } },
      );
      await GroundImage.create({
        ground_id:  ground.id,
        image:      req.file.publicUrl,
        is_primary: true,
      });
    }
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

/**
 * GET /ground-owner/bookings
 *
 * Optional filters, all additive — with none of them the query is exactly the
 * old one (newest first), so existing callers see no change:
 *   date=YYYY-MM-DD            bookings played on that day, ordered by start time
 *   date_from / date_to        an inclusive range of play dates
 *   status=confirmed,pending   one or more statuses
 *   ground_id                  one of the owner's grounds
 *   search                     booking reference, customer name or mobile
 */
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const BOOKING_STATUSES = ['pending', 'confirmed', 'cancelled', 'completed'];

exports.listBookings = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const { date, date_from, date_to, status, ground_id, search } = req.query;

    for (const [name, value] of [['date', date], ['date_from', date_from], ['date_to', date_to]]) {
      if (value && !DATE_RE.test(value)) return error(res, `${name} must be YYYY-MM-DD.`, 422);
    }

    const where = {};
    if (date) where.slot_date = date;
    else if (date_from || date_to) {
      where.slot_date = {};
      if (date_from) where.slot_date[Op.gte] = date_from;
      if (date_to)   where.slot_date[Op.lte] = date_to;
    }
    if (status) {
      const wanted = String(status).split(',').map((s) => s.trim()).filter((s) => BOOKING_STATUSES.includes(s));
      if (wanted.length) where.status = { [Op.in]: wanted };
    }
    if (search && String(search).trim()) {
      const term = `%${String(search).trim()}%`;
      where[Op.or] = [
        { booking_reference: { [Op.like]: term } },
        { '$user.name$':     { [Op.like]: term } },
        { '$user.mobile$':   { [Op.like]: term } },
      ];
    }

    const groundWhere = { owner_id: req.user.id };
    if (ground_id) groundWhere.id = ground_id;

    const byPlayDate = Boolean(date || date_from || date_to);

    await completeFinishedBookings({ Booking });
    const { count, rows } = await Booking.findAndCountAll({
      where,
      include: [
        {
          model: GroundSport, as: 'groundSport', required: true,
          include: [
            { model: Ground, as: 'ground', where: groundWhere, required: true },
            { model: Sport,  as: 'sport',  attributes: ['id', 'name'] },
          ],
        },
        { model: User, as: 'user', attributes: ['id', 'name', 'mobile', 'email'] },
        { model: Payment, as: 'paymentRecord', required: false },
      ],
      // Every include is to-one, so no row multiplication — this only stops
      // Sequelize wrapping the query in a subquery the $user.*$ search can't see.
      subQuery: false,
      limit, offset, distinct: true,
      order: byPlayDate
        ? [['slot_date', 'ASC'], ['slot_time_from', 'ASC']]
        : [['created_at', 'DESC']],
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

    // This used to be a bare `booking.update({ status: 'cancelled' })`, which
    // left every slot the booking held marked unavailable for ever — the venue
    // quietly lost that hour's inventory and no screen showed why. It now runs
    // the same release the customer's own cancel does.
    //
    // The transaction is opened here rather than inside the helper so the
    // notification rolls back with the cancellation: telling somebody their
    // game is off, and then failing to actually cancel it, is the one outcome
    // worse than either alone.
    const t = await sequelize.transaction();
    try {
      await cancelBookingAndReleaseSlots({ sequelize, BookedSlot, Slot }, booking, reason, t);

      const ground = booking.groundSport?.ground;
      await notify({
        recipientType: 'user',
        recipientId  : booking.user_id,
        type         : 'booking_cancelled_by_owner',
        title        : 'Your booking was cancelled',
        message      : `${ground?.name || 'The venue'} cancelled your booking on `
                     + `${booking.slot_date}. ${reason}`,
        referenceType: 'booking',
        referenceId  : booking.id,
        // A client route, not a URL — the app prefixes its own base. See §9.
        actionPath   : `/bookings/${booking.id}`,
      }, t);

      await t.commit();
    } catch (err) {
      await t.rollback();
      throw err;
    }

    return success(res, 'Booking cancelled.', booking);
  } catch (err) { return error(res, err.message, 500); }
};

/**
 * POST /ground-owner/bookings/:id/collect — the owner took the cash at the gate.
 *
 * A pay-at-ground booking takes a 10% advance online (see utils/pricing) and
 * leaves the rest owed. Nothing recorded that rest ever arriving, so the
 * owner's list kept saying "collect Rs.X" after the customer had already paid
 * and walked onto the pitch.
 *
 * This writes the payment the venue actually received: `payment_mode: offline`,
 * `payment_status: success`. Both values already existed on the model — no
 * column was added for this, and none should be.
 *
 * Deliberately NOT a Razorpay path: no gateway is involved, no money moves
 * through Playsher, and there is nothing to refund through the API if it is
 * recorded in error. That is also why it is owner-only and additive — the
 * customer app never calls it.
 *
 * Idempotent by refusing rather than by upserting: a second call answers 409
 * instead of writing a second payment row, because two rows would double the
 * venue's takings in any later reconciliation.
 */
exports.collectAtGround = async (req, res) => {
  try {
    const booking = await Booking.findOne({
      where  : { id: req.params.id },
      include: [{
        model: GroundSport, as: 'groundSport', required: true,
        include: [{ model: Ground, as: 'ground', where: { owner_id: req.user.id }, required: true }],
      }],
    });
    if (!booking) return error(res, 'Booking not found.', 404);
    if (booking.status === 'cancelled') return error(res, 'That booking was cancelled.', 409);

    const due = Number(booking.balance_due) || 0;
    if (due <= 0) return error(res, 'Nothing left to collect on this booking.', 409);

    const t = await sequelize.transaction();
    try {
      await Payment.create({
        booking_id       : booking.id,
        done_by_user_id  : booking.user_id,
        payment_status   : 'success',
        payment_mode     : 'offline',
        payment_method   : 'cash_at_ground',
        payment_timestamp: new Date(),
        amount           : due,
        currency         : 'INR',
      }, { transaction: t });

      // The money is in, so nothing is owed and the booking is settled. A
      // pay-at-ground booking sits `pending` until this moment: the advance
      // only ever held the slot.
      await booking.update(
        { balance_due: 0, status: booking.status === 'pending' ? 'confirmed' : booking.status },
        { transaction: t },
      );

      await notify({
        recipientType: 'user',
        recipientId  : booking.user_id,
        type         : 'booking_payment_collected',
        title        : 'Payment received',
        message      : `${booking.groundSport?.ground?.name || 'The venue'} recorded `
                     + `Rs.${due} received at the ground. Your booking is fully paid.`,
        referenceType: 'booking',
        referenceId  : booking.id,
        actionPath   : `/bookings/${booking.id}`,
      }, t);

      await t.commit();
    } catch (err) {
      await t.rollback();
      throw err;
    }

    await booking.reload();
    return success(res, 'Payment recorded.', booking);
  } catch (err) { return error(res, err.message, 500); }
};


// ── Settlements ───────────────────────────────────────────────────────────────

/**
 * GET /ground-owner/settlements — what this venue has earned, and what is owed.
 *
 * The admin panel has had `GET /admin/vendors` since the beginning; the owner
 * had no equivalent, so the person actually waiting for the money was the one
 * who could not see it.
 *
 * Read through `Payment.booking_id` rather than `bookings.payment_id`, because
 * a pay-at-ground booking has **two** payments — the 10% advance taken online
 * and the balance recorded at the gate — and a single `payment_id` column can
 * only point at one of them. Going the other way counts both.
 *
 * The split that matters to an owner is not paid/unpaid but *where the money
 * is*: cash they already hold, versus online money sitting with Playsher that
 * still has to reach their bank.
 */
exports.listSettlements = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);

    const groundIds = await ownedGroundIds(req.user.id);
    const empty = {
      online_total: 0, online_paid_out: 0, online_awaiting: 0,
      cash_collected: 0, payment_count: 0, payout_state: 'no_vendor',
    };
    if (groundIds.length === 0) {
      return success(res, 'Settlements retrieved.', { summary: empty, payments: [] },
        200, paginationMeta(0, page, limit));
    }

    // Money is only real once the payment succeeded. A pending or failed
    // attempt is not earnings and must never appear in a total an owner plans
    // around.
    const scope = {
      model  : Booking,
      as     : 'bookingRecord',
      required: true,
      attributes: ['id', 'booking_reference', 'slot_date', 'slot_time_from', 'status'],
      include: [{
        model: GroundSport, as: 'groundSport', required: true, attributes: ['id'],
        where: { ground_id: { [Op.in]: groundIds } },
        include: [
          { model: Ground, as: 'ground', attributes: ['id', 'name'] },
          { model: Sport,  as: 'sport',  attributes: ['id', 'name'] },
        ],
      }],
    };

    const { count, rows } = await Payment.findAndCountAll({
      where  : { payment_status: 'success' },
      include: [scope],
      limit, offset, distinct: true,
      order  : [['payment_timestamp', 'DESC'], ['id', 'DESC']],
    });

    // Totals span every payment, not just this page — an owner reading "owed"
    // off page 1 of 4 would plan around a quarter of their money.
    const all = await Payment.findAll({
      where     : { payment_status: 'success' },
      include   : [{ ...scope, attributes: ['id'] }],
      attributes: ['amount', 'payment_mode', 'vendor_payout_status'],
    });

    const num = (v) => parseFloat(v) || 0;
    const online = all.filter((p) => p.payment_mode === 'online');
    const summary = {
      online_total   : online.reduce((t, p) => t + num(p.amount), 0),
      online_paid_out: online.filter((p) => p.vendor_payout_status === 'transferred')
                             .reduce((t, p) => t + num(p.amount), 0),
      cash_collected : all.filter((p) => p.payment_mode === 'offline')
                          .reduce((t, p) => t + num(p.amount), 0),
      payment_count  : all.length,
    };
    summary.online_awaiting = summary.online_total - summary.online_paid_out;

    // `vendor_payout_status` is an admin-written column and nothing sets it
    // automatically, so on its own it reads "pending" for ever — including for
    // an owner whose money cannot move because Playsher has no account to send
    // it to. That one state is a fact we can check here, so it is *derived* for
    // display rather than written back: the stored column stays the admin's
    // record of what they actually did.
    const bank = await BankDetails.findOne({
      where: { user_id: req.user.id, user_type: 'ground_owner' },
      attributes: ['id'],
    });
    summary.has_bank_details = Boolean(bank);
    summary.payout_state = !bank && summary.online_awaiting > 0
      ? 'no_bank_details'
      : (summary.online_awaiting > 0 ? 'pending' : 'settled');

    const payments = rows.map((p) => {
      const b  = p.bookingRecord;
      const gs = b?.groundSport;
      return {
        id                  : p.id,
        amount              : num(p.amount),
        payment_mode        : p.payment_mode,
        payment_method      : p.payment_method,
        payment_timestamp   : p.payment_timestamp,
        // Cash never needed a payout — the owner already holds it. Reporting
        // it as "pending" would inflate what looks outstanding.
        vendor_payout_status: p.payment_mode === 'offline'
          ? 'collected_at_ground'
          : (!bank ? 'no_bank_details' : p.vendor_payout_status),
        booking_id          : b?.id ?? null,
        booking_reference   : b?.booking_reference ?? null,
        slot_date           : b?.slot_date ?? null,
        slot_time_from      : b?.slot_time_from ?? null,
        booking_status      : b?.status ?? null,
        ground_name         : gs?.ground?.name ?? null,
        sport_name          : gs?.sport?.name ?? null,
      };
    });

    return success(res, 'Settlements retrieved.', { summary, payments },
      200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

// ── Games ─────────────────────────────────────────────────────────────────────

/**
 * GET /ground-owner/games — every open game running at my grounds.
 *
 * Scoped by the *venue*, not by who published it. The endpoint used to list
 * only `hosted_by_ground_owner_id = me`, which is the rare case: almost every
 * game is opened by a customer on their own booking, so an owner's list was
 * empty while strangers were being invited onto their pitch. What an owner
 * needs to see is who is turning up at their ground.
 */
exports.listGames = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const groundIds = await ownedGroundIds(req.user.id);
    if (groundIds.length === 0) {
      return success(res, 'Games retrieved.', [], 200, paginationMeta(0, page, limit));
    }

    const where = {};
    if (req.query.visibility) where.visibility = req.query.visibility;

    // The venue filter lives two joins down, on the booking's ground.
    const scopedBooking = {
      ...BOOKING_INCLUDE,
      include: [{
        ...BOOKING_INCLUDE.include[0],
        include: [
          { ...BOOKING_INCLUDE.include[0].include[0], where: { id: { [Op.in]: groundIds } } },
          BOOKING_INCLUDE.include[0].include[1],
        ],
      }],
    };

    // Two phases, per `findGamesByIds`. Phase one carries only the booking
    // chain — every join in it is single-row, so it can filter and paginate
    // safely; adding the participants `hasMany` here is what breaks it.
    const order = [[{ model: Booking, as: 'booking' }, 'slot_date', 'DESC'], ['id', 'DESC']];
    const { count, rows } = await Game.findAndCountAll({
      where,
      include   : [scopedBooking],
      attributes: ['id'],
      order,
      limit, offset,
      subQuery  : false,
      distinct  : true,
    });

    const games = await findGamesByIds(rows.map((r) => r.id), order);
    return success(res, 'Games retrieved.', games.map((g) => serializeGame(g)), 200,
      paginationMeta(typeof count === 'number' ? count : rows.length, page, limit));
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
