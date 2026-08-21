const { Game, GameParticipant, Booking, GroundSport, Ground, Sport, User } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');


/**
 * The booking a game runs on, with enough of the venue to render a card.
 *
 * A game has no price of its own: it is hosted on a booking, and the money and
 * the venue both live there. The list query never included it, so clients had
 * nothing to read and every game rendered as ₹0 at an unnamed ground.
 */
const BOOKING_INCLUDE = {
  model: Booking,
  as: 'booking',
  attributes: ['id', 'slot_date', 'slot_time_from', 'slot_time_to', 'total_amount', 'status'],
  include: [{
    model: GroundSport,
    as: 'groundSport',
    attributes: ['id'],
    include: [
      {
        model: Ground,
        as: 'ground',
        // price_per_slot rather than the sport's old column, which nothing
        // reads. The per-player share below still divides the booking's stored
        // total, so it is unaffected either way.
        attributes: ['id', 'name', 'address', 'price_per_slot'],
      },
      { model: Sport, as: 'sport', attributes: ['id', 'name'] },
    ],
  }],
};

/**
 * Attach the per-player share to a game.
 *
 * Computed here rather than in the client: money is never the client's to
 * derive. Splits the booking total across the seats the host opened, which is
 * how these games are actually settled.
 */
function withPricing(game) {
  const json = typeof game.toJSON === 'function' ? game.toJSON() : game;
  const total = parseFloat(json.booking?.total_amount ?? 0);
  const seats = Number(json.max_participants) || 0;

  json.total_amount = Number.isFinite(total) ? total : 0;
  json.price_per_player =
    seats > 0 && Number.isFinite(total)
      ? Math.round((total / seats) * 100) / 100
      : 0;
  return json;
}

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
        BOOKING_INCLUDE,
      ],
      limit,
      offset,
      distinct: true,
    });
    return success(res, 'Games retrieved.', rows.map(withPricing), 200,
      paginationMeta(count, page, limit));
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
        BOOKING_INCLUDE,
      ],
    });
    if (!game) return error(res, 'Game not found.', 404);
    return success(res, 'Game retrieved.', withPricing(game));
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
