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

    // requireRole proves the caller is *a* ground owner, not that they own
    // this ground — without this any owner could reprice a competitor's venue.
    if (req.user.role === 'ground_owner') {
      const ground = await Ground.findOne({
        where: { id: req.params.groundId, owner_id: req.user.id, deleted_at: null },
      });
      if (!ground) return error(res, 'Forbidden.', 403);
    }

    // Whitelist: ground_id and sport_id are identity. Letting them through
    // would reassign every slot and booking already hanging off this row.
    // price_per_half_hour is deliberately absent. A slot costs what the
    // venue charges (grounds.price_per_slot); the old per-sport column is
    // kept for one release as a record and is read by nothing, so writing
    // to it would only create a figure that misleads whoever reads the row.
    const { min_slots, max_slots, player_counts,
            cancellation_policy, is_active } = req.body;
    const patch = {};
    if (min_slots           !== undefined) patch.min_slots           = min_slots;
    if (max_slots           !== undefined) patch.max_slots           = max_slots;
    if (player_counts       !== undefined) patch.player_counts       = player_counts;
    if (cancellation_policy !== undefined) patch.cancellation_policy = cancellation_policy;
    if (is_active           !== undefined) patch.is_active           = is_active;

    await gs.update(patch);
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
