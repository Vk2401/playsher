/**
 * Coach Panel Controllers — everything a signed-in coach does with their own
 * account. Every query is scoped to req.user.id; nothing here takes a coach id
 * from the request.
 */
const { Op, fn, col } = require('sequelize');
const {
  sequelize, Coach, CoachAvailability, CoachSlot, CoachGround, CoachBooking,
  CoachBookingSlot, Ground, GroundImage, GroundOwner, Sport, User, Notification,
} = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { pickCoachSelfFields } = require('../utils/coachFields');
const { ensureCoachSlotsForDate } = require('../utils/coachSlotGenerator');
const { appToday } = require('../utils/appTime');
const { notify } = require('../utils/notify');

/** What a session needs to be readable by the coach looking at it. */
const SESSION_INCLUDES = [
  { model: User,   as: 'user',   attributes: ['id', 'name', 'mobile', 'email'] },
  { model: Ground, as: 'ground', attributes: ['id', 'name', 'address', 'area', 'city'] },
];

const SESSION_ORDER = [['session_date', 'DESC'], ['time_from', 'DESC'], ['id', 'DESC']];

// ── Profile ───────────────────────────────────────────────────────────────────

/** GET /coach/profile */
exports.getProfile = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.user.id, {
      include: [{ model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] }],
    });
    if (!coach) return error(res, 'Coach not found.', 404);
    return success(res, 'Profile retrieved.', coach);
  } catch (err) { return error(res, err.message, 500); }
};

/** PUT /coach/profile (multipart: optional profile_image) */
exports.updateProfile = async (req, res) => {
  try {
    const coach = await Coach.findByPk(req.user.id);
    if (!coach) return error(res, 'Coach not found.', 404);

    const patch = pickCoachSelfFields(req.body);
    if (req.file) patch.profile_picture = req.file.publicUrl;

    if (Object.keys(patch).length === 0) {
      return error(res, 'No updatable fields supplied.');
    }
    if (patch.price_per_slot !== undefined && !(patch.price_per_slot >= 0)) {
      return error(res, 'Price per slot must be zero or more.');
    }

    await coach.update(patch);
    return success(res, 'Profile updated.', coach);
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /coach/dashboard */
exports.dashboard = async (req, res) => {
  try {
    const coachId = req.user.id;
    const today = appToday();

    const [coach, statusCounts, upcoming, approvedGrounds, pendingGrounds, earnings, unread] =
      await Promise.all([
        Coach.findByPk(coachId),
        CoachBooking.findAll({
          where: { coach_id: coachId },
          attributes: ['status', [fn('COUNT', col('id')), 'count']],
          group: ['status'],
          raw: true,
        }),
        CoachBooking.count({
          where: { coach_id: coachId, session_date: { [Op.gte]: today }, status: { [Op.in]: ['pending', 'confirmed'] } },
        }),
        CoachGround.count({ where: { coach_id: coachId, status: 'approved' } }),
        CoachGround.count({ where: { coach_id: coachId, status: 'pending' } }),
        // Only money the coach has actually earned — a pending request is not
        // income, and a rejected or cancelled one never was.
        CoachBooking.sum('total_amount', {
          where: { coach_id: coachId, status: { [Op.in]: ['confirmed', 'completed'] } },
        }),
        Notification.count({ where: { recipient_type: 'coach', recipient_id: coachId, is_read: false } }),
      ]);

    if (!coach) return error(res, 'Coach not found.', 404);

    const byStatus = statusCounts.reduce((acc, row) => {
      acc[row.status] = Number(row.count);
      return acc;
    }, {});

    return success(res, 'Dashboard retrieved.', {
      is_approved         : coach.is_approved,
      price_per_slot      : coach.price_per_slot,
      // A coach with no hours set can never be booked, so the panel says so
      // rather than leaving them wondering why nothing arrives.
      has_availability    : (await CoachAvailability.count({ where: { coach_id: coachId, is_closed: false } })) > 0,
      total_sessions      : Object.values(byStatus).reduce((a, b) => a + b, 0),
      pending_sessions    : byStatus.pending   || 0,
      confirmed_sessions  : byStatus.confirmed || 0,
      completed_sessions  : byStatus.completed || 0,
      cancelled_sessions  : (byStatus.cancelled || 0) + (byStatus.rejected || 0),
      upcoming_sessions   : upcoming,
      approved_grounds    : approvedGrounds,
      pending_ground_requests: pendingGrounds,
      total_earnings      : Number(earnings || 0),
      unread_notifications: unread,
    });
  } catch (err) { return error(res, err.message, 500); }
};

// ── Availability ──────────────────────────────────────────────────────────────

/** GET /coach/availability — the weekly template, one row per weekday */
exports.getAvailability = async (req, res) => {
  try {
    const rows = await CoachAvailability.findAll({
      where: { coach_id: req.user.id },
      order: [['day_of_week', 'ASC']],
    });
    return success(res, 'Availability retrieved.', rows);
  } catch (err) { return error(res, err.message, 500); }
};

/**
 * PUT /coach/availability
 * Body: { days: [{ day_of_week, start_time, end_time, is_closed }] }
 *
 * Replaces the whole week in one transaction — a partial save is what produces
 * a coach who is somehow open on Tuesday under the old hours and the new ones.
 */
exports.setAvailability = async (req, res) => {
  const days = Array.isArray(req.body.days) ? req.body.days : null;
  if (!days) return error(res, 'Send a "days" array.');

  for (const day of days) {
    const dow = Number(day.day_of_week);
    if (!Number.isInteger(dow) || dow < 0 || dow > 6) {
      return error(res, 'day_of_week must be 0 (Sunday) to 6 (Saturday).');
    }
    if (!day.is_closed) {
      if (!isTime(day.start_time) || !isTime(day.end_time)) {
        return error(res, 'start_time and end_time must be HH:MM times.');
      }
      if (toMinutes(day.end_time) - toMinutes(day.start_time) < 30) {
        return error(res, 'An open day needs at least one 30-minute block.');
      }
    }
  }

  const t = await sequelize.transaction();
  try {
    await CoachAvailability.destroy({ where: { coach_id: req.user.id }, transaction: t });
    await CoachAvailability.bulkCreate(
      days.map((day) => ({
        coach_id   : req.user.id,
        day_of_week: Number(day.day_of_week),
        start_time : day.is_closed ? '00:00:00' : normaliseTime(day.start_time),
        end_time   : day.is_closed ? '00:00:00' : normaliseTime(day.end_time),
        is_closed  : Boolean(day.is_closed),
      })),
      { transaction: t },
    );

    // Future slots were generated from the *old* hours. Anything still free is
    // dropped so it regenerates from the new template on the next read; a slot
    // someone already booked is left alone, because narrowing your hours does
    // not cancel a commitment you already made.
    //
    // Scoped to this coach's own future slots on both sides — reading every
    // held slot on the platform to answer a question about one coach's week
    // is a full-table scan that grows with the product.
    const futureIds = (await CoachSlot.findAll({
      where: { coach_id: req.user.id, slot_date: { [Op.gte]: appToday() } },
      attributes: ['id'],
      transaction: t,
      raw: true,
    })).map((r) => r.id);

    if (futureIds.length > 0) {
      const heldIds = (await CoachBookingSlot.findAll({
        where: { coach_slot_id: futureIds },
        attributes: ['coach_slot_id'],
        transaction: t,
        raw: true,
      })).map((r) => r.coach_slot_id);

      const freeIds = futureIds.filter((id) => !heldIds.includes(id));
      if (freeIds.length > 0) {
        await CoachSlot.destroy({ where: { id: freeIds }, transaction: t });
      }
    }

    await t.commit();
    const rows = await CoachAvailability.findAll({
      where: { coach_id: req.user.id },
      order: [['day_of_week', 'ASC']],
    });
    return success(res, 'Availability saved.', rows);
  } catch (err) {
    await t.rollback();
    return error(res, err.message, 500);
  }
};

/** GET /coach/slots?date=YYYY-MM-DD — the generated blocks for one day */
exports.listSlots = async (req, res) => {
  try {
    const date = req.query.date || appToday();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return error(res, 'date must be YYYY-MM-DD.');

    const slots = await ensureCoachSlotsForDate(req.user.id, date);
    const bookedIds = new Set(
      (await CoachBookingSlot.findAll({
        where: { coach_slot_id: slots.map((s) => s.id) },
        attributes: ['coach_slot_id'],
        raw: true,
      })).map((r) => r.coach_slot_id),
    );

    // "Unavailable" reads two ways to a coach — somebody booked it, or I blocked
    // it out myself — so the row says which.
    return success(res, 'Slots retrieved.', slots.map((s) => ({
      ...s.toJSON(),
      is_booked : bookedIds.has(s.id),
      is_blocked: !s.is_available && !bookedIds.has(s.id),
    })));
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /coach/slots/:id/block — take a block off the market */
exports.blockSlot = async (req, res) => {
  try {
    const slot = await CoachSlot.findOne({ where: { id: req.params.id, coach_id: req.user.id } });
    if (!slot) return error(res, 'Slot not found.', 404);

    const booked = await CoachBookingSlot.count({ where: { coach_slot_id: slot.id } });
    if (booked > 0) return error(res, 'That slot is already booked. Cancel the session instead.', 409);

    await slot.update({ is_available: false });
    return success(res, 'Slot blocked.', slot);
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /coach/slots/:id/unblock */
exports.unblockSlot = async (req, res) => {
  try {
    const slot = await CoachSlot.findOne({ where: { id: req.params.id, coach_id: req.user.id } });
    if (!slot) return error(res, 'Slot not found.', 404);

    const booked = await CoachBookingSlot.count({ where: { coach_slot_id: slot.id } });
    if (booked > 0) return error(res, 'That slot is held by a session.', 409);

    await slot.update({ is_available: true });
    return success(res, 'Slot reopened.', slot);
  } catch (err) { return error(res, err.message, 500); }
};

// ── Grounds ───────────────────────────────────────────────────────────────────

/** GET /coach/grounds — my registrations and where each one stands */
exports.listGroundLinks = async (req, res) => {
  try {
    const where = { coach_id: req.user.id };
    if (req.query.status) where.status = req.query.status;

    const rows = await CoachGround.findAll({
      where,
      include: [{
        model: Ground, as: 'ground',
        attributes: ['id', 'name', 'address', 'area', 'city', 'price_per_slot'],
        include: [{ model: GroundImage, as: 'images', attributes: ['id', 'image', 'is_primary'] }],
      }],
      order: [['created_at', 'DESC']],
    });
    return success(res, 'Ground registrations retrieved.', rows);
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /coach/grounds/available — grounds I could still ask to join */
exports.listAvailableGrounds = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);

    const taken = (await CoachGround.findAll({
      where: { coach_id: req.user.id, status: { [Op.in]: ['pending', 'approved'] } },
      attributes: ['ground_id'],
      raw: true,
    })).map((r) => r.ground_id);

    const where = {
      deleted_at: null,
      is_active : true,
      is_approved: true,
      ...(taken.length ? { id: { [Op.notIn]: taken } } : {}),
    };
    if (req.query.search) {
      where[Op.or] = [
        { name   : { [Op.like]: `%${req.query.search}%` } },
        { address: { [Op.like]: `%${req.query.search}%` } },
        { city   : { [Op.like]: `%${req.query.search}%` } },
      ];
    }
    if (req.query.city) where.city = req.query.city;

    const { count, rows } = await Ground.findAndCountAll({
      where,
      attributes: ['id', 'name', 'address', 'area', 'city', 'price_per_slot'],
      include: [{ model: GroundImage, as: 'images', attributes: ['id', 'image', 'is_primary'] }],
      limit, offset, distinct: true,
      order: [['name', 'ASC']],
    });
    return success(res, 'Grounds retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** POST /coach/grounds — ask a ground's owner to host me */
exports.requestGround = async (req, res) => {
  try {
    const groundId = Number(req.body.ground_id);
    if (!groundId) return error(res, 'ground_id is required.');

    const coach = await Coach.findByPk(req.user.id);
    if (!coach.is_approved) {
      return error(res, 'Your coach account is still pending admin approval.', 403);
    }

    const ground = await Ground.findOne({
      where: { id: groundId, deleted_at: null },
      include: [{ model: GroundOwner, as: 'owner', attributes: ['id', 'name'] }],
    });
    if (!ground) return error(res, 'Ground not found.', 404);

    const existing = await CoachGround.findOne({
      where: { coach_id: req.user.id, ground_id: groundId },
    });
    if (existing && existing.status === 'pending') {
      return error(res, 'You have already asked this ground; the owner has not answered yet.', 409);
    }
    if (existing && existing.status === 'approved') {
      return error(res, 'You are already registered at this ground.', 409);
    }

    const payload = {
      coach_id    : req.user.id,
      ground_id   : groundId,
      status      : 'pending',
      request_note: req.body.request_note || null,
      requested_at: new Date(),
      responded_at: null,
      response_note: null,
    };

    // A rejected row is reused rather than duplicated — one row per pair is
    // what the unique index promises, and it keeps the owner's history intact.
    const link = existing ? await existing.update(payload) : await CoachGround.create(payload);

    if (ground.owner_id) {
      await notify({
        recipientType: 'ground_owner',
        recipientId  : ground.owner_id,
        type         : 'coach_ground_requested',
        title        : 'A coach wants to register at your ground',
        message      : `${coach.name} has asked to coach at ${ground.name}. Approve or decline the request.`,
        referenceType: 'coach_ground',
        referenceId  : link.id,
        actionPath   : '/owner/coach-requests',
      });
    }

    return success(res, 'Request sent to the ground owner.', link, 201);
  } catch (err) { return error(res, err.message, 500); }
};

/** DELETE /coach/grounds/:id — withdraw a request or leave a ground */
exports.withdrawGround = async (req, res) => {
  try {
    const link = await CoachGround.findOne({
      where: { id: req.params.id, coach_id: req.user.id },
    });
    if (!link) return error(res, 'Registration not found.', 404);

    const upcoming = await CoachBooking.count({
      where: {
        coach_id    : req.user.id,
        ground_id   : link.ground_id,
        session_date: { [Op.gte]: appToday() },
        status      : { [Op.in]: ['pending', 'confirmed'] },
      },
    });
    if (upcoming > 0) {
      return error(res, 'You still have upcoming sessions booked at this ground.', 409);
    }

    await link.destroy();
    return success(res, 'Registration withdrawn.');
  } catch (err) { return error(res, err.message, 500); }
};

// ── Sessions ──────────────────────────────────────────────────────────────────

/** GET /coach/bookings */
exports.listBookings = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { coach_id: req.user.id };

    if (req.query.status) where.status = req.query.status;
    if (req.query.from) where.session_date = { ...(where.session_date || {}), [Op.gte]: req.query.from };
    if (req.query.to)   where.session_date = { ...(where.session_date || {}), [Op.lte]: req.query.to };
    if (req.query.upcoming === 'true') {
      where.session_date = { ...(where.session_date || {}), [Op.gte]: appToday() };
    }

    const { count, rows } = await CoachBooking.findAndCountAll({
      where,
      include: SESSION_INCLUDES,
      order: req.query.upcoming === 'true'
        ? [['session_date', 'ASC'], ['time_from', 'ASC']]
        : SESSION_ORDER,
      limit, offset, distinct: true,
    });
    return success(res, 'Sessions retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) { return error(res, err.message, 500); }
};

/** GET /coach/bookings/:id */
exports.getBooking = async (req, res) => {
  try {
    const booking = await CoachBooking.findOne({
      where: { id: req.params.id, coach_id: req.user.id },
      include: SESSION_INCLUDES,
    });
    if (!booking) return error(res, 'Session not found.', 404);
    return success(res, 'Session retrieved.', booking);
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /coach/bookings/:id/confirm */
exports.confirmBooking = async (req, res) => {
  try {
    const booking = await CoachBooking.findOne({
      where: { id: req.params.id, coach_id: req.user.id },
    });
    if (!booking) return error(res, 'Session not found.', 404);
    if (booking.status !== 'pending') {
      return error(res, `This session is already ${booking.status}.`, 409);
    }

    await booking.update({
      status   : 'confirmed',
      coach_note: req.body.coach_note || booking.coach_note,
      hold_expires_at: null,
    });

    await notify({
      recipientType: 'user',
      recipientId  : booking.user_id,
      type         : 'coach_booking_confirmed',
      title        : 'Your coaching session is confirmed',
      message      : `Your session on ${booking.session_date} at ${String(booking.time_from).slice(0, 5)} has been confirmed by your coach.`,
      referenceType: 'coach_booking',
      referenceId  : booking.id,
      actionPath   : `/coach-sessions/${booking.id}`,
    });

    return success(res, 'Session confirmed.', booking);
  } catch (err) { return error(res, err.message, 500); }
};

/** PATCH /coach/bookings/:id/reject */
exports.rejectBooking = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const booking = await CoachBooking.findOne({
      where: { id: req.params.id, coach_id: req.user.id },
      transaction: t,
    });
    if (!booking) { await t.rollback(); return error(res, 'Session not found.', 404); }
    if (!['pending', 'confirmed'].includes(booking.status)) {
      await t.rollback();
      return error(res, `This session is already ${booking.status}.`, 409);
    }

    await booking.update({
      status             : 'rejected',
      cancellation_reason: req.body.reason || null,
      hold_expires_at    : null,
    }, { transaction: t });
    await releaseSessionSlots(booking.id, t);
    await t.commit();

    await notify({
      recipientType: 'user',
      recipientId  : booking.user_id,
      type         : 'coach_booking_rejected',
      title        : 'Your coaching session was declined',
      message      : req.body.reason
        ? `The coach could not take your session on ${booking.session_date}: ${req.body.reason}`
        : `The coach could not take your session on ${booking.session_date}.`,
      referenceType: 'coach_booking',
      referenceId  : booking.id,
      actionPath   : `/coach-sessions/${booking.id}`,
    });

    return success(res, 'Session declined.', booking);
  } catch (err) {
    await t.rollback();
    return error(res, err.message, 500);
  }
};

/** PATCH /coach/bookings/:id/complete */
exports.completeBooking = async (req, res) => {
  try {
    const booking = await CoachBooking.findOne({
      where: { id: req.params.id, coach_id: req.user.id },
    });
    if (!booking) return error(res, 'Session not found.', 404);
    if (booking.status !== 'confirmed') {
      return error(res, 'Only a confirmed session can be marked complete.', 409);
    }
    await booking.update({ status: 'completed' });
    return success(res, 'Session marked complete.', booking);
  } catch (err) { return error(res, err.message, 500); }
};

// ── Shared helpers ────────────────────────────────────────────────────────────

/**
 * Give a cancelled session's blocks back to the coach's day.
 *
 * A block is only reopened if nothing else still holds it, so two overlapping
 * rows can never both hand the same half hour back.
 */
async function releaseSessionSlots(coachBookingId, transaction) {
  const rows = await CoachBookingSlot.findAll({
    where: { coach_booking_id: coachBookingId },
    transaction,
  });
  const slotIds = rows.map((r) => r.coach_slot_id);
  if (slotIds.length === 0) return;

  await CoachBookingSlot.destroy({ where: { coach_booking_id: coachBookingId }, transaction });

  const stillHeld = (await CoachBookingSlot.findAll({
    where: { coach_slot_id: slotIds },
    attributes: ['coach_slot_id'],
    transaction,
    raw: true,
  })).map((r) => r.coach_slot_id);

  const freeIds = slotIds.filter((id) => !stillHeld.includes(id));
  if (freeIds.length > 0) {
    await CoachSlot.update({ is_available: true }, { where: { id: freeIds }, transaction });
  }
}

function isTime(value) {
  return typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(value);
}

function toMinutes(value) {
  const [h, m] = String(value).split(':').map(Number);
  return h * 60 + m;
}

function normaliseTime(value) {
  return String(value).length === 5 ? `${value}:00` : String(value);
}

module.exports.releaseSessionSlots = releaseSessionSlots;
