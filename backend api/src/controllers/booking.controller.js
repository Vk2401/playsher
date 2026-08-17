const { sequelize, Booking, BookedSlot, Slot, GroundSport, Ground, User, Payment } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { ensureSlotsForDate } = require('../utils/slotGenerator');

exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = {};

    if (req.user.role === 'user') {
      where.user_id = req.user.id;
    } else if (req.user.role === 'ground_owner') {
      // Join to get bookings on this owner's grounds
      const { count, rows } = await Booking.findAndCountAll({
        where,
        include: [
          {
            model: GroundSport,
            as: 'groundSport',
            required: true,
            include: [{ model: Ground, as: 'ground', where: { owner_id: req.user.id }, required: true }],
          },
          { model: User, as: 'user', attributes: ['id', 'name', 'mobile'] },
        ],
        limit,
        offset,
        distinct: true,
      });
      return success(res, 'Bookings retrieved.', rows, 200, paginationMeta(count, page, limit));
    }

    const { count, rows } = await Booking.findAndCountAll({
      where,
      include: [
        { model: User, as: 'user', attributes: ['id', 'name', 'mobile'] },
        { model: GroundSport, as: 'groundSport', include: [{ model: Ground, as: 'ground' }] },
      ],
      limit,
      offset,
      distinct: true,
    });
    return success(res, 'Bookings retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const booking = await Booking.findByPk(req.params.id, {
      include: [
        { model: User, as: 'user', attributes: ['id', 'name', 'mobile', 'email'] },
        { model: GroundSport, as: 'groundSport', include: [{ model: Ground, as: 'ground' }] },
        { model: Slot, as: 'slots', through: { attributes: [] } },
        { model: Payment, as: 'paymentRecord' },
      ],
    });
    if (!booking) return error(res, 'Booking not found.', 404);
    if (req.user.role === 'user' && booking.user_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    return success(res, 'Booking retrieved.', booking);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.create = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const { ground_sport_id, slot_date, slot_ids, is_game, payment_method } = req.body;

    const gs = await GroundSport.findOne({ where: { id: ground_sport_id, is_active: true }, transaction: t });
    if (!gs) { await t.rollback(); return error(res, 'Ground sport not found or inactive.', 404); }

    // Validate slot count constraints
    if (slot_ids.length < gs.min_slots || slot_ids.length > gs.max_slots) {
      await t.rollback();
      return error(res, `Slot count must be between ${gs.min_slots} and ${gs.max_slots}.`);
    }

    // Ensure slots are generated for this date (safety net for lazy generation)
    await ensureSlotsForDate(ground_sport_id, slot_date, t);

    // Fetch and validate slots
    const slots = await Slot.findAll({
      where: { id: slot_ids, ground_sport_id, slot_date, is_available: true },
      transaction: t,
    });
    if (slots.length !== slot_ids.length) {
      await t.rollback();
      return error(res, 'Some slots are unavailable or invalid.');
    }

    const total_amount = parseFloat(gs.price_per_half_hour) * slots.length;
    const slot_time_from = slots[0].slot_start_time;
    const slot_time_to = slots[slots.length - 1].slot_end_time;

    const isOnline = payment_method === 'online';
    const bookingStatus = isOnline ? 'pending' : 'confirmed';

    const booking = await Booking.create({
      user_id: req.user.id,
      ground_sport_id,
      slot_date,
      slot_time_from,
      slot_time_to,
      total_amount,
      is_game: is_game || false,
      status: bookingStatus,
      payment_method: isOnline ? 'online' : 'pay_at_ground',
    }, { transaction: t });

    // Generate booking reference: YYYYMMDD-HHmm-HHmm-ID
    const refDate = slot_date.replace(/-/g, '');
    const refFrom = slot_time_from.replace(/:/g, '').slice(0, 4);
    const refTo   = slot_time_to.replace(/:/g, '').slice(0, 4);
    const booking_reference = `${refDate}-${refFrom}-${refTo}-${booking.id}`;
    await booking.update({ booking_reference }, { transaction: t });

    await BookedSlot.bulkCreate(slot_ids.map((sid) => ({ booking_id: booking.id, slot_id: sid })), { transaction: t });
    await Slot.update({ is_available: false }, { where: { id: slot_ids }, transaction: t });

    await t.commit();

    const responseData = booking.toJSON();
    if (isOnline) {
      responseData.requires_payment = true;
    }

    return success(res, 'Booking created.', responseData, 201);
  } catch (err) {
    await t.rollback();
    return error(res, err.message, 500);
  }
};

exports.cancel = async (req, res) => {
  try {
    const booking = await Booking.findByPk(req.params.id);
    if (!booking) return error(res, 'Booking not found.', 404);
    if (req.user.role === 'user' && booking.user_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    if (booking.status === 'cancelled') return error(res, 'Booking already cancelled.');
    const { cancellation_reason } = req.body;
    await booking.update({ status: 'cancelled', is_canceled: true, cancellation_reason });
    // Free up slots
    const bookedSlots = await BookedSlot.findAll({ where: { booking_id: booking.id } });
    const slotIds = bookedSlots.map((bs) => bs.slot_id);
    await Slot.update({ is_available: true }, { where: { id: slotIds } });
    return success(res, 'Booking cancelled.', booking);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const booking = await Booking.findByPk(req.params.id);
    if (!booking) return error(res, 'Booking not found.', 404);
    await booking.update(req.body);
    return success(res, 'Booking updated.', booking);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const booking = await Booking.findByPk(req.params.id);
    if (!booking) return error(res, 'Booking not found.', 404);
    await booking.destroy();
    return success(res, 'Booking deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
