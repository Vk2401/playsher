const { Slot, GroundSport } = require('../models');
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

exports.create = async (req, res) => {
  try {
    const gs = await GroundSport.findByPk(req.params.gsId);
    if (!gs) return error(res, 'Ground sport not found.', 404);
    const slot = await Slot.create({ ...req.body, ground_sport_id: gs.id });
    return success(res, 'Slot created.', slot, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const slot = await Slot.findOne({ where: { id: req.params.id, ground_sport_id: req.params.gsId } });
    if (!slot) return error(res, 'Slot not found.', 404);
    await slot.update(req.body);
    return success(res, 'Slot updated.', slot);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const slot = await Slot.findOne({ where: { id: req.params.id, ground_sport_id: req.params.gsId } });
    if (!slot) return error(res, 'Slot not found.', 404);
    await slot.destroy();
    return success(res, 'Slot deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
