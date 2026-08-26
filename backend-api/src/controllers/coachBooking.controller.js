/**
 * Coaching sessions, from the customer's side.
 *
 * The rule that governs ground bookings governs these too: the server is the
 * only thing that computes money. The client sends which coach, which day and
 * which blocks — never an amount.
 *
 * A session is created `pending` and stays there until the coach accepts it.
 * A coach is a person with a calendar of their own, so "booked" here means
 * "requested and held", and the coach's answer is what turns it into a
 * commitment. The blocks are held from the moment the request is made, because
 * offering the same half hour to a second customer while the first waits is
 * how you end up with two people on one court.
 */
const { Op } = require('sequelize');
const {
  sequelize, Coach, CoachSlot, CoachGround, CoachBooking, CoachBookingSlot,
  Ground, User,
} = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { ensureCoachSlotsForDate, isContiguous } = require('../utils/coachSlotGenerator');
const { isPastSlot, appToday } = require('../utils/appTime');
const { notify } = require('../utils/notify');
const { releaseSessionSlots } = require('./coachPanel.controller');

/**
 * Coaching sessions are settled with the coach on the day.
 *
 * The Razorpay integration is wired to `bookings` only, and there is no live
 * key yet (see the known gaps in CLAUDE.md). Rather than take an `online`
 * request the gateway cannot fulfil and leave a booking stuck at `pending
 * payment`, the endpoint says so plainly and books it as pay-at-venue.
 */
const PAYMENT_METHOD = 'pay_at_venue';

const SESSION_INCLUDES = [
  {
    model: Coach, as: 'coach',
    attributes: ['id', 'name', 'sport_name', 'profile_picture', 'mobile', 'price_per_slot'],
  },
  { model: Ground, as: 'ground', attributes: ['id', 'name', 'address', 'area', 'city'] },
];

/** POST /coach-bookings */
exports.create = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const { coach_id, ground_id, session_date, slot_ids, customer_note, payment_method } = req.body;

    if (payment_method && payment_method !== PAYMENT_METHOD) {
      await t.rollback();
      return error(res, 'Coaching sessions are paid at the venue for now; online payment is not available yet.');
    }
    if (!Array.isArray(slot_ids) || slot_ids.length === 0) {
      await t.rollback();
      return error(res, 'Pick at least one time slot.');
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(session_date || ''))) {
      await t.rollback();
      return error(res, 'session_date must be YYYY-MM-DD.');
    }

    const coach = await Coach.findOne({
      where: { id: coach_id, is_active: true, is_approved: true },
      transaction: t,
    });
    if (!coach) { await t.rollback(); return error(res, 'Coach not found.', 404); }

    // Read the price inside the transaction, like booking.controller does, so a
    // session is costed against the figure in force when it was taken.
    const pricePerSlot = parseFloat(coach.price_per_slot ?? 0);
    if (!(pricePerSlot > 0)) {
      await t.rollback();
      return error(res, 'This coach has not set a price yet, so they cannot be booked.', 409);
    }

    // A venue may only be chosen if its owner has agreed to host this coach.
    // Without this check a coach could be booked into a ground that has never
    // heard of them, and the owner would meet the session on the day.
    let ground = null;
    if (ground_id) {
      const link = await CoachGround.findOne({
        where: { coach_id: coach.id, ground_id, status: 'approved' },
        transaction: t,
      });
      if (!link) {
        await t.rollback();
        return error(res, 'This coach is not registered at that ground.', 409);
      }
      ground = await Ground.findByPk(ground_id, { transaction: t });
      if (!ground || ground.deleted_at) {
        await t.rollback();
        return error(res, 'Ground not found.', 404);
      }
    }

    await ensureCoachSlotsForDate(coach.id, session_date, t);

    const slots = await CoachSlot.findAll({
      where: { id: slot_ids, coach_id: coach.id, slot_date: session_date, is_available: true },
      order: [['slot_start_time', 'ASC']],
      transaction: t,
    });
    if (slots.length !== slot_ids.length) {
      await t.rollback();
      return error(res, 'Some of those times are no longer free.');
    }
    if (slots.some((s) => isPastSlot(session_date, s.slot_start_time))) {
      await t.rollback();
      return error(res, 'That time has already passed. Please pick a later slot.');
    }
    if (!isContiguous(slots)) {
      await t.rollback();
      return error(res, 'Pick one unbroken stretch of time.');
    }

    const total = pricePerSlot * slots.length;
    const booking = await CoachBooking.create({
      user_id       : req.user.id,
      coach_id      : coach.id,
      ground_id     : ground ? ground.id : null,
      session_date,
      time_from     : slots[0].slot_start_time,
      time_to       : slots[slots.length - 1].slot_end_time,
      total_amount  : total,
      advance_amount: 0,
      balance_due   : total,
      status        : 'pending',
      payment_method: PAYMENT_METHOD,
      customer_note : customer_note || null,
    }, { transaction: t });

    const ref = `CS-${String(session_date).replace(/-/g, '')}`
      + `-${String(slots[0].slot_start_time).replace(/:/g, '').slice(0, 4)}-${booking.id}`;
    await booking.update({ booking_reference: ref }, { transaction: t });

    await CoachBookingSlot.bulkCreate(
      slots.map((s) => ({ coach_booking_id: booking.id, coach_slot_id: s.id })),
      { transaction: t },
    );
    await CoachSlot.update(
      { is_available: false },
      { where: { id: slots.map((s) => s.id) }, transaction: t },
    );

    await t.commit();

    // Told after the commit, so nobody is notified about a session that rolled
    // back. The coach is the point of this whole module — they find out that
    // somebody booked them without having to go looking.
    const customer = await User.findByPk(req.user.id, { attributes: ['id', 'name'] });
    const when = `${session_date} at ${String(booking.time_from).slice(0, 5)}`;
    await notify({
      recipientType: 'coach',
      recipientId  : coach.id,
      type         : 'coach_booking_created',
      title        : 'New session request',
      message      : `${customer?.name || 'A player'} booked you for ${when}`
        + `${ground ? ` at ${ground.name}` : ''}. Accept or decline it from your sessions.`,
      referenceType: 'coach_booking',
      referenceId  : booking.id,
      actionPath   : `/coach/bookings/${booking.id}`,
    });

    // The owner is hosting this on their court, so it belongs in their day too.
    if (ground?.owner_id) {
      await notify({
        recipientType: 'ground_owner',
        recipientId  : ground.owner_id,
        type         : 'coach_session_at_ground',
        title        : 'A coaching session was booked at your ground',
        message      : `${coach.name} has a session at ${ground.name} on ${when}.`,
        referenceType: 'coach_booking',
        referenceId  : booking.id,
        actionPath   : '/owner/coach-sessions',
      });
    }

    const payload = booking.toJSON();
    payload.awaiting_coach_confirmation = true;
    return success(res, 'Session requested. Your coach will confirm shortly.', payload, 201);
  } catch (err) {
    await t.rollback();
    return error(res, err.message, 500);
  }
};

/** GET /coach-bookings — my coaching sessions */
exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { user_id: req.user.id };
    if (req.query.status) where.status = req.query.status;

    const { count, rows } = await CoachBooking.findAndCountAll({
      where,
      include: SESSION_INCLUDES,
      order: [['session_date', 'DESC'], ['time_from', 'DESC'], ['id', 'DESC']],
      limit, offset, distinct: true,
    });
    return success(res, 'Sessions retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** GET /coach-bookings/:id */
exports.show = async (req, res) => {
  try {
    const booking = await CoachBooking.findByPk(req.params.id, { include: SESSION_INCLUDES });
    if (!booking) return error(res, 'Session not found.', 404);
    if (booking.user_id !== req.user.id) return error(res, 'Forbidden.', 403);
    return success(res, 'Session retrieved.', booking);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** PATCH /coach-bookings/:id/cancel */
exports.cancel = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const booking = await CoachBooking.findByPk(req.params.id, { transaction: t });
    if (!booking) { await t.rollback(); return error(res, 'Session not found.', 404); }
    if (booking.user_id !== req.user.id) { await t.rollback(); return error(res, 'Forbidden.', 403); }
    if (!['pending', 'confirmed'].includes(booking.status)) {
      await t.rollback();
      return error(res, `This session is already ${booking.status}.`, 409);
    }

    await booking.update({
      status             : 'cancelled',
      cancellation_reason: req.body.cancellation_reason || null,
      hold_expires_at    : null,
    }, { transaction: t });
    await releaseSessionSlots(booking.id, t);
    await t.commit();

    await notify({
      recipientType: 'coach',
      recipientId  : booking.coach_id,
      type         : 'coach_booking_cancelled',
      title        : 'A session was cancelled',
      message      : `The session on ${booking.session_date} at `
        + `${String(booking.time_from).slice(0, 5)} was cancelled by the player.`,
      referenceType: 'coach_booking',
      referenceId  : booking.id,
      actionPath   : `/coach/bookings/${booking.id}`,
    });

    return success(res, 'Session cancelled.', booking);
  } catch (err) {
    await t.rollback();
    return error(res, err.message, 500);
  }
};

/**
 * GET /coach-bookings/upcoming — the next sessions, for the app's home screen.
 * Kept separate from `list` so the home screen does not have to page through a
 * customer's whole history to find the one card it shows.
 */
exports.upcoming = async (req, res) => {
  try {
    const rows = await CoachBooking.findAll({
      where: {
        user_id     : req.user.id,
        status      : { [Op.in]: ['pending', 'confirmed'] },
        session_date: { [Op.gte]: appToday() },
      },
      include: SESSION_INCLUDES,
      order  : [['session_date', 'ASC'], ['time_from', 'ASC']],
      limit  : 5,
    });
    return success(res, 'Upcoming sessions retrieved.', rows);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
