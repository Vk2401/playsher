const { Slot, GroundSport, Ground } = require('../models');
const { success, error } = require('../utils/response');
const { ensureSlotsForDate } = require('../utils/slotGenerator');

exports.list = async (req, res) => {
  try {
    const groundSportId = req.params.gsId;

    // If a specific date is requested, ensure slots are lazily generated
    if (req.query.date) {
      const slots = await ensureSlotsForDate(Number(groundSportId), req.query.date);
      return success(res, 'Slots retrieved.', slots);
    }

    const where = { ground_sport_id: groundSportId };
    const slots = await Slot.findAll({ where, order: [['slot_date', 'ASC'], ['slot_start_time', 'ASC']] });
    return success(res, 'Slots retrieved.', slots);
  } catch (err) {
    return error(res, err.message, 500);
  }
};


/**
 * Resolve a ground sport, proving the caller may write to it.
 *
 * requireRole only proves the caller is *a* ground owner. Without this check any
 * owner could create, edit or delete slots on another owner's ground — opening
 * a competitor's closed slots, or deleting their whole day.
 *
 * @returns {Promise<{ gs: object } | { status: number, message: string }>}
 */
async function resolveWritableGroundSport(groundSportId, user) {
  const gs = await GroundSport.findByPk(groundSportId);
  if (!gs) return { status: 404, message: 'Ground sport not found.' };

  if (user.role === 'ground_owner') {
    const ground = await Ground.findOne({
      where: { id: gs.ground_id, owner_id: user.id, deleted_at: null },
    });
    if (!ground) return { status: 403, message: 'Forbidden.' };
  }
  return { gs };
}

exports.create = async (req, res) => {
  try {
    const resolved = await resolveWritableGroundSport(req.params.gsId, req.user);
    if (resolved.status) return error(res, resolved.message, resolved.status);

    // Whitelist: ground_sport_id comes from the path, not the body, so a slot
    // cannot be created against someone else's ground sport.
    const { slot_date, slot_start_time, slot_end_time, is_available } = req.body;
    const slot = await Slot.create({
      slot_date,
      slot_start_time,
      slot_end_time,
      is_available: is_available === undefined ? true : is_available,
      ground_sport_id: resolved.gs.id,
    });
    return success(res, 'Slot created.', slot, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const resolved = await resolveWritableGroundSport(req.params.gsId, req.user);
    if (resolved.status) return error(res, resolved.message, resolved.status);

    const slot = await Slot.findOne({ where: { id: req.params.id, ground_sport_id: req.params.gsId } });
    if (!slot) return error(res, 'Slot not found.', 404);

    // ground_sport_id is identity: letting the body set it would move the slot
    // — and any booking already attached to it — onto another ground.
    const { slot_date, slot_start_time, slot_end_time, is_available } = req.body;
    const patch = {};
    if (slot_date       !== undefined) patch.slot_date       = slot_date;
    if (slot_start_time !== undefined) patch.slot_start_time = slot_start_time;
    if (slot_end_time   !== undefined) patch.slot_end_time   = slot_end_time;
    if (is_available    !== undefined) patch.is_available    = is_available;
    if (Object.keys(patch).length === 0) return error(res, 'No updatable fields supplied.');

    await slot.update(patch);
    return success(res, 'Slot updated.', slot);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const resolved = await resolveWritableGroundSport(req.params.gsId, req.user);
    if (resolved.status) return error(res, resolved.message, resolved.status);

    const slot = await Slot.findOne({ where: { id: req.params.id, ground_sport_id: req.params.gsId } });
    if (!slot) return error(res, 'Slot not found.', 404);
    await slot.destroy();
    return success(res, 'Slot deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
