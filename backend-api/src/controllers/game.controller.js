/**
 * Open games — the part of Playsher that is not a booking.
 *
 * A game is a booked slot with seats opened on it. The host has already paid
 * for the ground; what they are publishing is the *other half* of the pitch,
 * and the discovery feed exists so a player with nobody to play with can find
 * it. That is the whole product difference from a turf-booking app, so the
 * feed is a first-class query rather than "list every row in `games`".
 *
 * Three rules hold this module together:
 *
 * 1. **A game has no money of its own.** The venue and the total both live on
 *    the booking, and the per-player share is divided here, on the server —
 *    never taken from or derived by a client (§7 of CLAUDE.md, same rule as
 *    ground and coach pricing).
 * 2. **A game's status is derived, never stored.** `open`, `full`,
 *    `in_progress`, `completed` and `cancelled` all fall out of the booking's
 *    date and time plus the seats taken, so a game cannot sit in the feed
 *    claiming to be open after it has been played.
 * 3. **The host holds a seat.** Creating a game writes the host in as a
 *    participant, because "3/10 joined" that silently excludes the one person
 *    guaranteed to be there is a lie the fill bar tells on every card.
 */
const { Op } = require('sequelize');
const {
  sequelize, Game, GameParticipant, Booking, GroundSport, Ground, User,
} = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { appToday, isPastSlot } = require('../utils/appTime');
const { notify } = require('../utils/notify');
const {
  GAME_LEVELS, SEATED, BOOKING_INCLUDE, PARTICIPANTS_INCLUDE,
  GAME_INCLUDES, serialize, isJoinable, findGameWhole,
} = require('../utils/gameView');

// ── Query building ────────────────────────────────────────────────────────────

/**
 * Turn the feed's query string into a date window.
 *
 * `when` is the shorthand the app's date chips send; `date_from`/`date_to` are
 * the explicit form. Everything is a wall-clock YYYY-MM-DD in the app timezone,
 * never a UTC instant — a game at 21:00 IST must not roll into tomorrow's chip.
 * Either end may come back `null`, meaning "open-ended on that side".
 */
function dateWindow(query) {
  const today = appToday();
  const shift = (days) => {
    const d = new Date(`${today}T00:00:00Z`);
    d.setUTCDate(d.getUTCDate() + days);
    return d.toISOString().slice(0, 10);
  };

  if (query.date) return { from: query.date, to: query.date };

  switch (String(query.when || '').toLowerCase()) {
    case 'today':    return { from: today, to: today };
    case 'tomorrow': return { from: shift(1), to: shift(1) };
    case 'weekend': {
      // Saturday and Sunday of the week we are currently in; once the weekend
      // has started it means "the rest of this one", not the next.
      const dow = new Date(`${today}T00:00:00Z`).getUTCDay(); // 0=Sun … 6=Sat
      const toSaturday = (6 - dow + 7) % 7;
      return dow === 0
        ? { from: today, to: today }
        : { from: shift(toSaturday), to: shift(toSaturday + 1) };
    }
    case 'week': return { from: today, to: shift(6) };
    default:
      return {
        // A caller that named only an upper bound is asking for history, so
        // the lower bound stays open rather than snapping to today and
        // returning nothing.
        from: query.date_from || (query.date_to ? null : today),
        to  : query.date_to || null,
      };
  }
}

/**
 * The `where` for the booking join, given the feed's filters.
 *
 * Cancelled bookings never appear: the slot is gone, so the game on it is not
 * a game any more. Past games are hidden unless the caller asks for them —
 * Discover is somewhere to find a game to play, not an archive; "My games" is
 * the archive.
 */
function bookingWhere(query) {
  const where = { is_canceled: false, status: { [Op.ne]: 'cancelled' } };

  const explicitDates = Boolean(query.date || query.when || query.date_from || query.date_to);
  if (String(query.include_past) === 'true' && !explicitDates) return where;

  const { from, to } = dateWindow(query);
  if (from && to) where.slot_date = { [Op.between]: [from, to] };
  else if (from) where.slot_date = { [Op.gte]: from };
  else if (to) where.slot_date = { [Op.lte]: to };

  return where;
}

/**
 * Fetch a page of games matching the feed's filters.
 *
 * Two queries on purpose. The filters live on joined tables and the payload
 * needs a `hasMany` of participants; asking for both at once makes Sequelize
 * choose between a subquery that cannot see the joins and a flat join that
 * miscounts the page. So the first query picks the page's IDs using only
 * single-row joins, and the second loads those rows in full.
 */
async function findGamesPage({ where, query, order, page, limit, offset }) {
  const groundWhere = {};
  if (query.city) groundWhere.city = query.city;
  if (query.ground_id) groundWhere.id = query.ground_id;

  const sportWhere = query.sport_id ? { id: query.sport_id } : null;

  const search = String(query.search || '').trim();
  const searchWhere = search
    ? {
      [Op.or]: [
        { game_name: { [Op.like]: `%${search}%` } },
        { description: { [Op.like]: `%${search}%` } },
        { '$booking.groundSport.ground.name$': { [Op.like]: `%${search}%` } },
        { '$booking.groundSport.ground.area$': { [Op.like]: `%${search}%` } },
        { '$booking.groundSport.sport.name$': { [Op.like]: `%${search}%` } },
      ],
    }
    : null;

  const filterInclude = {
    ...BOOKING_INCLUDE,
    where  : bookingWhere(query),
    include: [{
      ...BOOKING_INCLUDE.include[0],
      include: [
        { ...BOOKING_INCLUDE.include[0].include[0], where: Object.keys(groundWhere).length ? groundWhere : undefined },
        { ...BOOKING_INCLUDE.include[0].include[1], required: Boolean(sportWhere), where: sportWhere || undefined },
      ],
    }],
  };

  const { count, rows } = await Game.findAndCountAll({
    // `Op.and`, not a spread: both `where` and `searchWhere` can carry an
    // `Op.or`, and spreading one over the other drops whichever came first —
    // which on /games/mine is the clause that makes the list mine.
    where     : searchWhere ? { [Op.and]: [where, searchWhere] } : where,
    include   : [filterInclude],
    attributes: ['id'],
    order,
    limit,
    offset,
    subQuery  : false,
    distinct  : true,
  });

  if (rows.length === 0) return { count: typeof count === 'number' ? count : 0, games: [] };

  // Ordered again: `IN (…)` does not preserve the page's order.
  const games = await Game.findAll({
    where  : { id: rows.map((r) => r.id) },
    include: GAME_INCLUDES,
    order,
  });

  return { count: typeof count === 'number' ? count : rows.length, games, page, limit, offset };
}

/** Sort orders the feed offers, keyed by the `sort` query param. */
function orderFor(sort) {
  const bookingPath = [{ model: Booking, as: 'booking' }];
  switch (String(sort || '').toLowerCase()) {
    case 'newest':
      return [['created_at', 'DESC'], ['id', 'DESC']];
    case 'latest':
      return [[...bookingPath, 'slot_date', 'DESC'], [...bookingPath, 'slot_time_from', 'DESC'], ['id', 'DESC']];
    default: // 'soonest' — the game that kicks off next is the one worth joining
      return [[...bookingPath, 'slot_date', 'ASC'], [...bookingPath, 'slot_time_from', 'ASC'], ['id', 'ASC']];
  }
}

// ── Endpoints ─────────────────────────────────────────────────────────────────

/**
 * GET /games — the discovery feed.
 *
 * Public, but better when signed in: `optionalAuth` supplies the viewer, which
 * is what marks the games they already hold a seat in.
 */
exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const viewerId = req.user?.role === 'user' ? req.user.id : null;

    const where = { is_active: true };
    where.visibility = req.query.visibility === 'private' ? 'private' : 'public';
    if (req.query.level && GAME_LEVELS.includes(req.query.level)) where.game_level = req.query.level;
    if (req.query.game_level && GAME_LEVELS.includes(req.query.game_level)) where.game_level = req.query.game_level;

    // A private feed is only ever the viewer's own — there is no path that
    // lists somebody else's invite-only games.
    if (where.visibility === 'private') {
      if (!viewerId) return error(res, 'Sign in to see your private games.', 401);
      where.hosted_by_user_id = viewerId;
    }

    const { count, games } = await findGamesPage({
      where,
      query : req.query,
      order : orderFor(req.query.sort),
      page, limit, offset,
    });

    let payload = games.map((g) => serialize(g, viewerId));

    // Applied after serialisation because both are derived, not stored.
    if (String(req.query.only_open) === 'true') {
      payload = payload.filter((g) => g.status === 'open');
    }
    if (String(req.query.exclude_mine) === 'true' && viewerId) {
      payload = payload.filter((g) => !g.is_host && !g.is_joined);
    }

    return success(res, 'Games retrieved.', payload, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * GET /games/mine — the games I host and the games I am playing in.
 *
 * One call rather than two: the app's "My games" tab shows both, and a player
 * thinks of them as one list with a badge, not as two separate concepts. Past
 * games are included — this list *is* the archive.
 */
exports.mine = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const viewerId = req.user.id;

    const seatedIn = await GameParticipant.findAll({
      where     : { user_id: viewerId, status: { [Op.in]: SEATED } },
      attributes: ['game_id'],
    });
    const seatedIds = seatedIn.map((p) => p.game_id);

    const where = {
      [Op.or]: [
        { hosted_by_user_id: viewerId },
        ...(seatedIds.length ? [{ id: { [Op.in]: seatedIds } }] : []),
      ],
    };

    // Upcoming and past are two lists with opposite orders — soonest-first for
    // the game you are about to walk to, most-recent-first for the archive —
    // so the caller says which one it wants rather than getting one order that
    // reads backwards for half of them.
    const scope = ['past', 'all'].includes(req.query.scope) ? req.query.scope : 'upcoming';
    const today = appToday();
    const yesterday = new Date(`${today}T00:00:00Z`);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);

    const scoped = scope === 'past'
      ? { date_to: yesterday.toISOString().slice(0, 10) }
      : scope === 'all'
        ? { include_past: 'true' }
        : { date_from: today };

    const { count, games } = await findGamesPage({
      where,
      query : { ...req.query, ...scoped },
      order : orderFor(req.query.sort || (scope === 'upcoming' ? 'soonest' : 'latest')),
      page, limit, offset,
    });

    const payload = games
      .map((g) => serialize(g, viewerId))
      .map((g) => ({ ...g, relation: g.is_host ? 'hosting' : 'playing' }));

    return success(res, 'Your games retrieved.', payload, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** GET /games/:id */
exports.show = async (req, res) => {
  try {
    const viewerId = req.user?.role === 'user' ? req.user.id : null;
    const game = await findGameWhole(req.params.id);
    if (!game) return error(res, 'Game not found.', 404);

    const payload = serialize(game, viewerId);

    // A private game is the host's and their invitees' — anyone else gets the
    // same answer as a game that does not exist, rather than a 403 that
    // confirms it is there.
    if (payload.visibility === 'private'
      && !payload.is_host && !payload.my_participant_status
      && req.user?.role !== 'admin') {
      return error(res, 'Game not found.', 404);
    }

    return success(res, 'Game retrieved.', payload);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * POST /games — open seats on a slot you have already booked.
 *
 * The booking is proved to be the host's, unplayed and not already carrying a
 * game before anything is written. Without those checks a player could publish
 * seats on somebody else's booking, or on a slot that finished last week.
 */
exports.create = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const {
      booking_id, game_name, max_participants, game_level, visibility, description, image,
    } = req.body;

    const booking = await Booking.findByPk(booking_id, {
      include: [{
        model  : GroundSport,
        as     : 'groundSport',
        include: [{ model: Ground, as: 'ground', attributes: ['id', 'name', 'owner_id'] }],
      }],
      transaction: t,
    });
    if (!booking) { await t.rollback(); return error(res, 'That booking does not exist.', 404); }

    // Whose booking is it? A player hosts on their own; an owner hosts on a
    // booking at their own ground.
    const ownerId = booking.groundSport?.ground?.owner_id ?? null;
    const isOwn = req.user.role === 'user'
      ? booking.user_id === req.user.id
      : ownerId === req.user.id;
    if (!isOwn) { await t.rollback(); return error(res, 'You can only host a game on your own booking.', 403); }

    if (booking.is_canceled || booking.status === 'cancelled') {
      await t.rollback();
      return error(res, 'That booking was cancelled.', 409);
    }
    if (isPastSlot(booking.slot_date, booking.slot_time_from)) {
      await t.rollback();
      return error(res, 'That slot has already started. Host a game on an upcoming booking.', 409);
    }

    const existing = await Game.findOne({ where: { booking_id: booking.id }, transaction: t });
    if (existing) {
      await t.rollback();
      return error(res, 'This booking already has a game on it.', 409);
    }

    const game = await Game.create({
      game_name,
      booking_id      : booking.id,
      max_participants: max_participants || 10,
      game_level      : game_level || 'intermediate',
      visibility      : visibility || 'public',
      description     : description || null,
      image           : image || null,
      is_active       : true,
      hosted_by_user_id        : req.user.role === 'user' ? req.user.id : null,
      hosted_by_ground_owner_id: req.user.role === 'ground_owner' ? req.user.id : null,
    }, { transaction: t });

    // The host holds a seat. A fill bar that reads "0/10" on a game the host
    // is certainly playing in is wrong on the card, in the list and in the
    // capacity check that decides when the game is full.
    if (req.user.role === 'user') {
      await GameParticipant.create({
        game_id  : game.id,
        user_id  : req.user.id,
        status   : 'joined',
        joined_at: new Date(),
      }, { transaction: t });
    }

    // The slot is now a game, so the booking says so — the owner's day sheet
    // and the player's own booking both read this flag.
    if (!booking.is_game) await booking.update({ is_game: true }, { transaction: t });

    await t.commit();

    const full = await findGameWhole(game.id);
    const payload = serialize(full, req.user.role === 'user' ? req.user.id : null);

    // The ground is hosting strangers now, not just the person who booked.
    if (ownerId && payload.visibility === 'public') {
      await notify({
        recipientType: 'ground_owner',
        recipientId  : ownerId,
        type         : 'game_published',
        title        : 'An open game was published at your ground',
        message      : `"${payload.game_name}" is open for players on ${payload.slot_date} `
          + `at ${String(payload.slot_time_from || '').slice(0, 5)}.`,
        referenceType: 'game',
        referenceId  : game.id,
        actionPath   : '/owner/games',
      });
    }

    return success(res, 'Your game is live. Players can find it in Discover now.', payload, 201);
  } catch (err) {
    await t.rollback();
    return error(res, err.message, 500);
  }
};

/** Is this request coming from the game's host (or an admin)? */
function isHostOf(game, user) {
  if (!user) return false;
  if (user.role === 'user') return game.hosted_by_user_id === user.id;
  if (user.role === 'ground_owner') return game.hosted_by_ground_owner_id === user.id;
  return false;
}

/** PUT /games/:id */
exports.update = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id);
    if (!game) return error(res, 'Game not found.', 404);
    if (!isHostOf(game, req.user) && req.user.role !== 'admin') return error(res, 'Forbidden.', 403);

    // Shrinking a game below the seats already taken would put it permanently
    // over capacity — the people who joined are not being removed.
    if (req.body.max_participants != null) {
      const seated = await GameParticipant.count({
        where: { game_id: game.id, status: { [Op.in]: SEATED } },
      });
      if (Number(req.body.max_participants) < seated) {
        return error(res, `${seated} players have already joined. You cannot set the limit below that.`, 409);
      }
    }

    await game.update(req.body);

    const full = await findGameWhole(game.id);
    return success(res, 'Game updated.', serialize(full, req.user.role === 'user' ? req.user.id : null));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * PATCH /games/:id/cancel — close the game without touching the booking.
 *
 * Deliberately not a delete: the slot is still booked and still paid for, and
 * the players who joined need to be told rather than to find an empty list.
 */
exports.cancel = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id, { include: [BOOKING_INCLUDE, PARTICIPANTS_INCLUDE] });
    if (!game) return error(res, 'Game not found.', 404);
    if (!isHostOf(game, req.user) && req.user.role !== 'admin') return error(res, 'Forbidden.', 403);
    if (!game.is_active) return error(res, 'This game is already cancelled.', 409);

    await game.update({ is_active: false });

    const payload = serialize(game, req.user.role === 'user' ? req.user.id : null);
    const others  = (game.participants || [])
      .filter((p) => SEATED.includes(p.status) && p.user_id !== game.hosted_by_user_id);

    await Promise.all(others.map((p) => notify({
      recipientType: 'user',
      recipientId  : p.user_id,
      type         : 'game_cancelled',
      title        : 'A game you joined was called off',
      message      : `"${payload.game_name}" on ${payload.slot_date} at `
        + `${String(payload.slot_time_from || '').slice(0, 5)} was cancelled by the host.`,
      referenceType: 'game',
      referenceId  : game.id,
      actionPath   : `/games/${game.id}`,
    })));

    return success(res, 'Game cancelled. Everyone who joined has been told.', payload);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** DELETE /games/:id */
exports.destroy = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id);
    if (!game) return error(res, 'Game not found.', 404);
    if (!isHostOf(game, req.user) && req.user.role !== 'admin') return error(res, 'Forbidden.', 403);
    await game.destroy();
    return success(res, 'Game deleted.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * POST /games/:id/join — take one of the open seats.
 *
 * Inside a transaction with the game row locked: two players tapping "Join" on
 * the last seat within the same second is the ordinary case on a game that is
 * nearly full, and the capacity check is worth nothing if it is not serialised.
 */
exports.join = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    // The lock is taken on the game row by itself. Locking the joined booking
    // and ground as well — which `FOR UPDATE` over an include would do — would
    // block the venue's other bookings for the length of a join.
    const locked = await Game.findByPk(req.params.id, {
      lock: t.LOCK.UPDATE,
      transaction: t,
    });
    if (!locked) { await t.rollback(); return error(res, 'Game not found.', 404); }

    const game = await findGameWhole(locked.id, { transaction: t });
    const payload = serialize(game, req.user.id);

    if (payload.is_host) {
      await t.rollback();
      return error(res, 'You are hosting this game — you already have a seat.', 409);
    }
    if (payload.visibility === 'private' && !payload.my_participant_status) {
      await t.rollback();
      return error(res, 'This game is invite-only.', 403);
    }
    if (payload.is_joined) {
      await t.rollback();
      return error(res, 'You have already joined this game.', 409);
    }
    if (!isJoinable(payload)) {
      await t.rollback();
      const reason = {
        full       : 'This game is full.',
        cancelled  : 'This game was cancelled.',
        in_progress: 'This game has already started.',
        completed  : 'This game has already been played.',
      }[payload.status] || 'This game is not open.';
      return error(res, reason, 409);
    }

    const [participant, created] = await GameParticipant.findOrCreate({
      where      : { game_id: game.id, user_id: req.user.id },
      defaults   : { status: 'joined', joined_at: new Date() },
      transaction: t,
    });
    if (!created) await participant.update({ status: 'joined', joined_at: new Date() }, { transaction: t });

    await t.commit();

    // The host finds out somebody is coming without having to reopen the app.
    if (game.hosted_by_user_id) {
      const player = await User.findByPk(req.user.id, { attributes: ['id', 'name'] });
      const left   = Math.max(0, payload.spots_left - 1);
      await notify({
        recipientType: 'user',
        recipientId  : game.hosted_by_user_id,
        type         : 'game_player_joined',
        title        : 'Someone joined your game',
        message      : `${player?.name || 'A player'} joined "${payload.game_name}". `
          + (left > 0 ? `${left} ${left === 1 ? 'spot' : 'spots'} left.` : 'Your game is now full.'),
        referenceType: 'game',
        referenceId  : game.id,
        actionPath   : `/games/${game.id}`,
      });
    }

    const full = await findGameWhole(game.id);
    return success(res, "You're in. See you at the ground.", serialize(full, req.user.id));
  } catch (err) {
    await t.rollback();
    return error(res, err.message, 500);
  }
};

/**
 * DELETE /games/:id/leave — give the seat back.
 *
 * A host cannot leave their own game; the slot is theirs and the other players
 * are there because of them. Cancelling is the honest action, and it tells
 * everybody.
 */
exports.leave = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id, { include: [BOOKING_INCLUDE] });
    if (!game) return error(res, 'Game not found.', 404);
    if (game.hosted_by_user_id === req.user.id) {
      return error(res, 'You are hosting this game. Cancel it instead of leaving.', 409);
    }

    const deleted = await GameParticipant.destroy({
      where: { game_id: game.id, user_id: req.user.id },
    });
    if (!deleted) return error(res, "You haven't joined this game.", 404);

    if (game.hosted_by_user_id) {
      const player = await User.findByPk(req.user.id, { attributes: ['id', 'name'] });
      await notify({
        recipientType: 'user',
        recipientId  : game.hosted_by_user_id,
        type         : 'game_player_left',
        title        : 'A player dropped out',
        message      : `${player?.name || 'A player'} left "${game.game_name}". `
          + 'The spot is open again.',
        referenceType: 'game',
        referenceId  : game.id,
        actionPath   : `/games/${game.id}`,
      });
    }

    return success(res, 'You left the game.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** POST /games/:id/invite */
exports.invite = async (req, res) => {
  try {
    const game = await Game.findByPk(req.params.id, { include: [BOOKING_INCLUDE] });
    if (!game) return error(res, 'Game not found.', 404);
    if (!isHostOf(game, req.user)) return error(res, 'Only the host can invite players.', 403);

    const { user_ids } = req.body;
    const records = user_ids.map((uid) => ({ game_id: game.id, user_id: uid, status: 'invited' }));
    await GameParticipant.bulkCreate(records, { ignoreDuplicates: true });

    const when = `${game.booking?.slot_date || ''} at ${String(game.booking?.slot_time_from || '').slice(0, 5)}`;
    await Promise.all(user_ids.map((uid) => notify({
      recipientType: 'user',
      recipientId  : uid,
      type         : 'game_invite',
      title        : "You're invited to a game",
      message      : `You have been invited to "${game.game_name}" ${when.trim()}.`,
      referenceType: 'game',
      referenceId  : game.id,
      actionPath   : `/games/${game.id}`,
    })));

    return success(res, 'Invitations sent.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/** PATCH /games/:id/invite/:userId/respond */
exports.respondInvite = async (req, res) => {
  try {
    const participant = await GameParticipant.findOne({
      where: { game_id: req.params.id, user_id: req.params.userId },
    });
    if (!participant) return error(res, 'Invitation not found.', 404);
    if (participant.user_id !== req.user.id) return error(res, 'Forbidden.', 403);

    const { status } = req.body;

    // Accepting is joining, so it goes through the same capacity gate — an
    // invitation is not a reserved seat.
    if (status === 'accepted') {
      const game = await Game.findByPk(req.params.id, {
        include: [BOOKING_INCLUDE, PARTICIPANTS_INCLUDE],
      });
      if (!game) return error(res, 'Game not found.', 404);
      const payload = serialize(game, req.user.id);
      if (!isJoinable(payload)) {
        return error(res, payload.status === 'full'
          ? 'This game filled up before you accepted.'
          : 'This game is no longer open.', 409);
      }
    }

    await participant.update({
      status,
      ...(status === 'accepted' ? { joined_at: new Date() } : {}),
    });

    return success(res, `Invitation ${status}.`, participant);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
