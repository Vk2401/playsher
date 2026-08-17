const { Game, GameParticipant, Booking, User } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');

exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = { is_active: true };
    if (req.query.visibility) where.visibility = req.query.visibility;
    else where.visibility = 'public';

    const { count, rows } = await Game.findAndCountAll({
      where,
      include: [
        { model: User, as: 'hostedByUser', attributes: ['id', 'name'] },
        { model: GameParticipant, as: 'participants', attributes: ['id', 'user_id', 'status'] },
      ],
      limit,
      offset,
      distinct: true,
    });
    return success(res, 'Games retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.show = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id, {
      include: [
        { model: User, as: 'hostedByUser', attributes: ['id', 'name'] },
        { model: GameParticipant, as: 'participants', include: [{ model: User, as: 'user', attributes: ['id', 'name'] }] },
        { model: Booking, as: 'booking' },
      ],
    });
    if (!game) return error(res, 'Game not found.', 404);
    return success(res, 'Game retrieved.', game);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.create = async (req, res) => {
  try {
    const data = { ...req.body };
    if (req.user.role === 'user') data.hosted_by_user_id = req.user.id;
    else if (req.user.role === 'ground_owner') data.hosted_by_ground_owner_id = req.user.id;
    const game = await Game.create(data);
    return success(res, 'Game created.', game, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.update = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id);
    if (!game) return error(res, 'Game not found.', 404);
    const isHost =
      (req.user.role === 'user' && game.hosted_by_user_id === req.user.id) ||
      (req.user.role === 'ground_owner' && game.hosted_by_ground_owner_id === req.user.id);
    if (!isHost && req.user.role !== 'admin') return error(res, 'Forbidden.', 403);
    await game.update(req.body);
    return success(res, 'Game updated.', game);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.destroy = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id);
    if (!game) return error(res, 'Game not found.', 404);
    const isHost =
      (req.user.role === 'user' && game.hosted_by_user_id === req.user.id) ||
      (req.user.role === 'ground_owner' && game.hosted_by_ground_owner_id === req.user.id);
    if (!isHost && req.user.role !== 'admin') return error(res, 'Forbidden.', 403);
    await game.destroy();
    return success(res, 'Game deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.join = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id);
    if (!game || !game.is_active) return error(res, 'Game not found.', 404);
    if (game.visibility !== 'public') return error(res, 'Cannot join private game directly.', 403);
    const count = await GameParticipant.count({ where: { game_id: game.id, status: 'joined' } });
    if (count >= game.max_participants) return error(res, 'Game is full.');
    const [participant, created] = await GameParticipant.findOrCreate({
      where: { game_id: game.id, user_id: req.user.id },
      defaults: { status: 'joined', joined_at: new Date() },
    });
    if (!created) await participant.update({ status: 'joined', joined_at: new Date() });
    return success(res, 'Joined game.', participant);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.leave = async (req, res) => {
  try {
    const deleted = await GameParticipant.destroy({ where: { game_id: req.params.id, user_id: req.user.id } });
    if (!deleted) return error(res, 'Not a participant.', 404);
    return success(res, 'Left game.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.invite = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id);
    if (!game) return error(res, 'Game not found.', 404);
    const isHost =
      (req.user.role === 'user' && game.hosted_by_user_id === req.user.id) ||
      (req.user.role === 'ground_owner' && game.hosted_by_ground_owner_id === req.user.id);
    if (!isHost) return error(res, 'Only host can invite.', 403);
    const { user_ids } = req.body;
    const records = user_ids.map((uid) => ({ game_id: game.id, user_id: uid, status: 'invited' }));
    await GameParticipant.bulkCreate(records, { ignoreDuplicates: true });
    return success(res, 'Invitations sent.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.respondInvite = async (req, res) => {
  try {
    const participant = await GameParticipant.findOne({
      where: { game_id: req.params.id, user_id: req.params.userId },
    });
    if (!participant) return error(res, 'Invitation not found.', 404);
    if (participant.user_id !== req.user.id) return error(res, 'Forbidden.', 403);
    const { status } = req.body;
    const updates = { status };
    if (status === 'accepted') updates.joined_at = new Date();
    await participant.update(updates);
    return success(res, `Invitation ${status}.`, participant);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
