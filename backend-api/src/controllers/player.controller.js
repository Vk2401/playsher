/**
 * Players, and the graph between them.
 *
 * A game is played with strangers, so the app needs a way to say who somebody
 * is, to find them again, and to bring them along next time. That is what this
 * controller is: a public profile, a handle to find it by, and a directed
 * follow graph that makes "invite the people I actually play with" a two-tap
 * action instead of a WhatsApp trawl.
 *
 * Two rules run through all of it:
 *
 * 1. **A profile is public to signed-in players, and carries no contact
 *    details.** Everything is shaped by `utils/playerView`, which whitelists
 *    the fields — `mobile` and `email` are not among them.
 * 2. **A phone number finds an account; it never comes back from one.** Search
 *    by number is an exact full-number match, never a prefix, so this endpoint
 *    cannot be walked to enumerate the user base. You can look up a number you
 *    already have; you cannot discover numbers you do not.
 */
const { Op, fn, col, literal } = require('sequelize');
const {
  sequelize, User, UserFollow, Game, GameParticipant, Sport, UserSportPreference,
} = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { normalizeIndianMobile } = require('../utils/mobile.utils');
const { normalise } = require('../utils/username');
const { notify } = require('../utils/notify');
const {
  PUBLIC_ATTRIBUTES, CARD_ATTRIBUTES, toCard, toProfile, followedIdsAmong,
} = require('../utils/playerView');
const { serialize: serializeGame, findGamesByIds } = require('../utils/gameView');

/** Only real, reachable accounts appear anywhere in here. */
const VISIBLE = { deleted_at: null, is_active: true };

/** Participant states that mean somebody actually held a seat. */
const SEATED = ['joined', 'accepted'];

/**
 * Resolve `:handle` — a username or a numeric id — to a user row.
 *
 * Both forms exist because a client links by whichever it holds: a notification
 * carries an id, a shared profile link carries the handle. An all-digit string
 * is unambiguously an id, because `utils/username` refuses a handle without a
 * letter in it.
 */
async function findByHandle(handle) {
  const raw = String(handle ?? '').trim();
  if (!raw) return null;

  if (/^\d+$/.test(raw)) {
    return User.findOne({ where: { id: raw, ...VISIBLE }, attributes: PUBLIC_ATTRIBUTES });
  }
  return User.findOne({
    where: { username: normalise(raw), ...VISIBLE },
    attributes: PUBLIC_ATTRIBUTES,
  });
}

// ── Search ────────────────────────────────────────────────────────────────────

/**
 * GET /players/search?q= — find somebody to invite.
 *
 * Three ways in, in priority order:
 *
 * - **A full phone number** you already have. Exact match on the normalised
 *   `+91XXXXXXXXXX` and nothing else: no prefix, no partial, no wildcard. That
 *   is the difference between "look up my friend's number" and "download the
 *   user table one digit at a time".
 * - **A handle**, prefix-first so typing `rav` surfaces `ravi99` before
 *   `dhruvravi`.
 * - **A name**, which is a convenience rather than an identity — two players
 *   can share one, which is exactly why handles exist.
 *
 * Never returns the caller, deleted or deactivated accounts, or any contact
 * detail.
 */
exports.search = async (req, res) => {
  try {
    const viewerId = req.user.id;
    const { page, limit, offset } = getPagination(req.query);
    const raw = String(req.query.q ?? '').trim();

    if (raw.length < 2) {
      return error(res, 'Type at least 2 characters, or a full mobile number.');
    }

    const mobile = normalizeIndianMobile(raw);
    const handle = normalise(raw);

    let where;
    if (mobile) {
      // Exact, and only exact.
      where = { mobile, ...VISIBLE };
    } else {
      where = {
        ...VISIBLE,
        [Op.or]: [
          { username: { [Op.like]: `%${handle}%` } },
          { name: { [Op.like]: `%${raw}%` } },
        ],
      };
    }

    const { count, rows } = await User.findAndCountAll({
      where: { ...where, id: { [Op.ne]: viewerId } },
      attributes: CARD_ATTRIBUTES,
      // A prefix hit before a contains hit, then alphabetically, so the handle
      // somebody is actually typing surfaces first.
      order: mobile
        ? [['id', 'ASC']]
        : [
          [literal(`CASE WHEN \`username\` LIKE ${sequelize.escape(`${handle}%`)} THEN 0 ELSE 1 END`), 'ASC'],
          ['username', 'ASC'],
        ],
      limit,
      offset,
    });

    const followed = await followedIdsAmong(UserFollow, viewerId, rows.map((r) => r.id));
    const data = rows.map((u) => toCard(u, { isFollowing: followed.has(u.id) }));

    return success(res, 'Players retrieved.', data, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * GET /players/teammates — people I have actually played with.
 *
 * The default list in the invite sheet, ahead of search: the players most
 * likely to be invited to your next game are the ones who were in your last
 * one, and they are the only names you can offer somebody before they have
 * typed anything.
 *
 * Ordered by how often you have shared a game, so a regular ranks above a
 * one-off.
 */
exports.teammates = async (req, res) => {
  try {
    const viewerId = req.user.id;
    const { page, limit, offset } = getPagination(req.query);

    // Every game I held a seat in, whether I hosted it or joined it.
    const mine = await GameParticipant.findAll({
      where     : { user_id: viewerId, status: { [Op.in]: SEATED } },
      attributes: ['game_id'],
    });
    const gameIds = mine.map((r) => r.game_id);
    if (gameIds.length === 0) {
      return success(res, 'Teammates retrieved.', [], 200, paginationMeta(0, page, limit));
    }

    const rows = await GameParticipant.findAll({
      where     : {
        game_id: { [Op.in]: gameIds },
        user_id: { [Op.ne]: viewerId },
        status : { [Op.in]: SEATED },
      },
      attributes: ['user_id', [fn('COUNT', col('game_id')), 'shared']],
      group     : ['user_id'],
      order     : [[literal('shared'), 'DESC']],
      limit,
      offset,
      raw       : true,
    });

    const ids = rows.map((r) => r.user_id);
    if (ids.length === 0) {
      return success(res, 'Teammates retrieved.', [], 200, paginationMeta(0, page, limit));
    }

    const users = await User.findAll({
      where     : { id: { [Op.in]: ids }, ...VISIBLE },
      attributes: CARD_ATTRIBUTES,
    });
    const byId = new Map(users.map((u) => [u.id, u]));
    const followed = await followedIdsAmong(UserFollow, viewerId, ids);

    // `IN (…)` does not preserve the ranking, so the order is reapplied here.
    const data = rows
      .map((r) => {
        const user = byId.get(r.user_id);
        if (!user) return null;
        return { ...toCard(user, { isFollowing: followed.has(r.user_id) }), games_together: Number(r.shared) };
      })
      .filter(Boolean);

    return success(res, 'Teammates retrieved.', data, 200, paginationMeta(data.length, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// ── Profile ───────────────────────────────────────────────────────────────────

/** GET /players/:handle — one player's public profile. */
exports.show = async (req, res) => {
  try {
    const viewerId = req.user.id;
    const user = await findByHandle(req.params.handle);
    if (!user) return error(res, 'Player not found.', 404);

    const isSelf = user.id === viewerId;

    const [followers, following, gamesHosted, gamesPlayed, preferences, outbound, inbound] =
      await Promise.all([
        UserFollow.count({ where: { following_id: user.id } }),
        UserFollow.count({ where: { follower_id: user.id } }),
        Game.count({ where: { hosted_by_user_id: user.id } }),
        GameParticipant.count({ where: { user_id: user.id, status: { [Op.in]: SEATED } } }),
        UserSportPreference.findAll({
          where  : { user_id: user.id },
          include: [{ model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] }],
        }),
        isSelf ? null : UserFollow.findOne({ where: { follower_id: viewerId, following_id: user.id } }),
        isSelf ? null : UserFollow.findOne({ where: { follower_id: user.id, following_id: viewerId } }),
      ]);

    const payload = toProfile(user, {
      followers,
      following,
      gamesHosted,
      gamesPlayed,
      sports: preferences
        .map((p) => p.sport)
        .filter(Boolean)
        .map((s) => ({ id: s.id, name: s.name, image: s.image })),
      isFollowing: Boolean(outbound),
      followsYou : Boolean(inbound),
      isSelf,
    });

    return success(res, 'Player retrieved.', payload);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * GET /players/:handle/games — the public games this player is in.
 *
 * What makes a profile worth opening: you are deciding whether to join their
 * game, or whether to invite them to yours. Private games are never listed —
 * they are not the viewer's to see.
 */
exports.games = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const user = await findByHandle(req.params.handle);
    if (!user) return error(res, 'Player not found.', 404);

    const seats = await GameParticipant.findAll({
      where     : { user_id: user.id, status: { [Op.in]: SEATED } },
      attributes: ['game_id'],
    });
    const ids = seats.map((s) => s.game_id);
    if (ids.length === 0) {
      return success(res, 'Games retrieved.', [], 200, paginationMeta(0, page, limit));
    }

    // Two phases, for the reason `findGamesByIds` documents: the page's ids
    // first, then the rows loaded whole. Asking for the includes and a limit
    // together makes Sequelize build a subquery the nested venue join cannot
    // resolve against.
    const where = { id: { [Op.in]: ids }, visibility: 'public', is_active: true };
    const order = [['id', 'DESC']];

    const [count, page_] = await Promise.all([
      Game.count({ where }),
      Game.findAll({ where, attributes: ['id'], order, limit, offset }),
    ]);

    const games = await findGamesByIds(page_.map((r) => r.id), order);
    return success(res, 'Games retrieved.', games.map((row) => serializeGame(row, req.user.id)), 200,
      paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// ── Follow graph ──────────────────────────────────────────────────────────────

/** POST /players/:id/follow */
exports.follow = async (req, res) => {
  try {
    const viewerId = req.user.id;
    const targetId = Number(req.params.id);

    if (targetId === viewerId) return error(res, 'You cannot follow yourself.', 409);

    const target = await User.findOne({
      where: { id: targetId, ...VISIBLE },
      attributes: ['id', 'name', 'username'],
    });
    if (!target) return error(res, 'Player not found.', 404);

    const [, created] = await UserFollow.findOrCreate({
      where   : { follower_id: viewerId, following_id: targetId },
      defaults: { follower_id: viewerId, following_id: targetId },
    });

    // Told once, on the follow that actually happened — a repeated tap on an
    // already-followed player must not send a second notification.
    if (created) {
      const me = await User.findByPk(viewerId, { attributes: ['id', 'name', 'username'] });
      await notify({
        recipientType: 'user',
        recipientId  : targetId,
        type         : 'player_followed',
        title        : 'You have a new follower',
        message      : `${me?.name || 'A player'} started following you.`,
        referenceType: 'user',
        referenceId  : viewerId,
        actionPath   : `/players/${me?.username || viewerId}`,
      });
    }

    const followers = await UserFollow.count({ where: { following_id: targetId } });
    return success(res, created ? `You now follow ${target.name}.` : 'Already following.', {
      is_following   : true,
      followers_count: followers,
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** DELETE /players/:id/follow */
exports.unfollow = async (req, res) => {
  try {
    const viewerId = req.user.id;
    const targetId = Number(req.params.id);

    await UserFollow.destroy({ where: { follower_id: viewerId, following_id: targetId } });

    // Idempotent on purpose: unfollowing someone you do not follow is not an
    // error, it is the state the caller asked for.
    const followers = await UserFollow.count({ where: { following_id: targetId } });
    return success(res, 'Unfollowed.', { is_following: false, followers_count: followers });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** Shared body of the two list endpoints — they differ only in which column is fixed. */
async function followList(req, res, { column, alias, message }) {
  const { page, limit, offset } = getPagination(req.query);
  const user = await findByHandle(req.params.handle);
  if (!user) return error(res, 'Player not found.', 404);

  const { count, rows } = await UserFollow.findAndCountAll({
    where  : { [column]: user.id },
    include: [{
      model     : User,
      as        : alias,
      required  : true,
      where     : VISIBLE,
      attributes: CARD_ATTRIBUTES,
    }],
    order  : [['created_at', 'DESC']],
    limit, offset,
  });

  const people = rows.map((r) => r[alias]).filter(Boolean);
  const followed = await followedIdsAmong(UserFollow, req.user.id, people.map((p) => p.id));

  const data = people.map((p) => toCard(p, {
    isFollowing: followed.has(p.id),
    isSelf     : p.id === req.user.id,
  }));

  return success(res, message, data, 200, paginationMeta(count, page, limit));
}

/** GET /players/:handle/followers — who follows them. */
exports.followers = async (req, res) => {
  try {
    return await followList(req, res, {
      column : 'following_id',
      alias  : 'follower',
      message: 'Followers retrieved.',
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** GET /players/:handle/following — who they follow. */
exports.following = async (req, res) => {
  try {
    return await followList(req, res, {
      column : 'follower_id',
      alias  : 'followed',
      message: 'Following retrieved.',
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

module.exports.findByHandle = findByHandle;
module.exports.VISIBLE = VISIBLE;
