const { GroundSport, Sport, Ground } = require('../models');
const { success, error } = require('../utils/response');

exports.list = async (req, res) => {
  try {
    const groundSports = await GroundSport.findAll({
      where: { ground_id: req.params.groundId },
      include: [{ model: Sport, as: 'sport' }],
    });
    return success(res, 'Ground sports retrieved.', groundSports);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const gs = await GroundSport.findOne({
      where: { id: req.params.id, ground_id: req.params.groundId },
      include: [{ model: Sport, as: 'sport' }, { model: Ground, as: 'ground' }],
    });
    if (!gs) return error(res, 'Ground sport not found.', 404);
    return success(res, 'Ground sport retrieved.', gs);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.create = async (req, res) => {
  try {
    const ground = await Ground.findOne({ where: { id: req.params.groundId, deleted_at: null } });
    if (!ground) return error(res, 'Ground not found.', 404);
    if (req.user.role === 'ground_owner' && ground.owner_id !== req.user.id) {
      return error(res, 'Forbidden.', 403);
    }
    const gs = await GroundSport.create({ ...req.body, ground_id: ground.id });
    return success(res, 'Ground sport created.', gs, 201);
  } catch (err) {
    if (err.name === 'SequelizeUniqueConstraintError') {
      return error(res, 'This sport is already mapped to the ground.');
    }
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const gs = await GroundSport.findOne({ where: { id: req.params.id, ground_id: req.params.groundId } });
    if (!gs) return error(res, 'Ground sport not found.', 404);
    await gs.update(req.body);
    return success(res, 'Ground sport updated.', gs);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const gs = await GroundSport.findOne({ where: { id: req.params.id, ground_id: req.params.groundId } });
    if (!gs) return error(res, 'Ground sport not found.', 404);
    await gs.destroy();
    return success(res, 'Ground sport deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
