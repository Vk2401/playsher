/**
 * What a game looks like once it leaves the API.
 *
 * Pulled out of the controller because three panels answer the same question —
 * the app's Discover feed, the admin table and the ground owner's list — and a
 * game whose seat count, price share or status is computed differently in each
 * of them is three different games. This module owns the Sequelize includes
 * that fetch a game whole, and the one function that flattens it.
 *
 * Pure: no `req`, no `res`, no HTTP.
 */
const { Op } = require('sequelize');
const {
  Game, GameParticipant, Booking, GroundSport, Ground, Sport, User,
} = require('../models');
const { appToday, isPastSlot, isPastSlotEnd } = require('./appTime');

const GAME_LEVELS = [
  'newbie', 'beginner', 'intermediate', 'advanced', 'professional', 'ultra_professional',
];

/** Participant rows that actually hold a seat. */
const SEATED = ['joined', 'accepted'];

// ── Includes ──────────────────────────────────────────────────────────────────

/**
 * The booking a game runs on, with enough of the venue to render a card.
 *
 * A game has no price, date or venue of its own: it is hosted on a booking and
 * all three live there. The list query once omitted it entirely, so clients had
 * nothing to read and every game rendered as ₹0 at an unnamed ground.
 */
const BOOKING_INCLUDE = {
  model     : Booking,
  as        : 'booking',
  required  : true,
  attributes: ['id', 'slot_date', 'slot_time_from', 'slot_time_to', 'total_amount', 'status', 'is_canceled'],
  include   : [{
    model     : GroundSport,
    as        : 'groundSport',
    required  : true,
    attributes: ['id'],
    include   : [
      {
        model   : Ground,
        as      : 'ground',
        required: true,
        // price_per_slot rather than the sport's old column, which nothing
        // reads. The per-player share below still divides the booking's stored
        // total, so it is unaffected either way.
        attributes: ['id', 'name', 'address', 'area', 'city', 'price_per_slot', 'latitude', 'longitude'],
      },
      { model: Sport, as: 'sport', required: false, attributes: ['id', 'name', 'image'] },
    ],
  }],
};

const HOST_INCLUDE = {
  model     : User,
  as        : 'hostedByUser',
  required  : false,
  attributes: ['id', 'name', 'profile_picture'],
};

const PARTICIPANTS_INCLUDE = {
  model     : GameParticipant,
  as        : 'participants',
  required  : false,
  attributes: ['id', 'user_id', 'status', 'joined_at'],
  include   : [{ model: User, as: 'user', required: false, attributes: ['id', 'name', 'profile_picture'] }],
};

// ── Serialisation ─────────────────────────────────────────────────────────────

/**
 * One game, flattened for the clients.
 *
 * Both the nested objects and the flat convenience keys are emitted: the app's
 * `GameModel` reads the nested booking, the admin panel's table reads the flat
 * `ground_name` / `sport_name`, and neither has to learn the other's shape.
 */
function serialize(game, viewerId = null) {
  const json = typeof game.toJSON === 'function' ? game.toJSON() : game;

  const booking = json.booking || null;
  const gs      = booking?.groundSport || null;
  const ground  = gs?.ground || null;
  const sport   = gs?.sport || null;

  const participants = Array.isArray(json.participants) ? json.participants : [];
  const seated       = participants.filter((p) => SEATED.includes(p.status));
  const seats        = Number(json.max_participants) || 0;
  const total        = parseFloat(booking?.total_amount ?? 0);

  const hostUserId = json.hosted_by_user_id ?? null;
  const mine       = viewerId ? participants.find((p) => p.user_id === viewerId) : null;

  json.participants = participants.map((p) => ({
    ...p,
    is_host: Boolean(hostUserId && p.user_id === hostUserId),
  }));

  // ── Money: divided here, never by a client ──────────────────────────────────
  json.total_amount     = Number.isFinite(total) ? total : 0;
  json.price_per_player = seats > 0 && Number.isFinite(total)
    ? Math.round((total / seats) * 100) / 100
    : 0;

  // ── Seats ──────────────────────────────────────────────────────────────────
  json.joined_count = seated.length;
  json.spots_left   = Math.max(0, seats - seated.length);
  json.is_full      = seats > 0 && seated.length >= seats;

  // ── Where and when ─────────────────────────────────────────────────────────
  json.ground_id      = ground?.id ?? null;
  json.ground_name    = ground?.name ?? null;
  json.ground_area    = ground?.area ?? null;
  json.ground_city    = ground?.city ?? null;
  json.ground_address = ground?.address ?? null;
  json.sport_id       = sport?.id ?? null;
  json.sport_name     = sport?.name ?? null;
  json.sport_image    = sport?.image ?? null;
  json.slot_date      = booking?.slot_date ?? null;
  json.slot_time_from = booking?.slot_time_from ?? null;
  json.slot_time_to   = booking?.slot_time_to ?? null;
  json.host_name      = json.hostedByUser?.name ?? json.hostedByOwner?.name ?? null;
  json.host_avatar    = json.hostedByUser?.profile_picture ?? null;

  json.status = derivedStatus(json, booking, seated.length, seats);

  // ── The viewer's own relationship to this game ─────────────────────────────
  json.is_host              = Boolean(viewerId && hostUserId && hostUserId === viewerId);
  json.is_joined            = Boolean(mine && SEATED.includes(mine.status));
  json.is_invited           = Boolean(mine && mine.status === 'invited');
  json.my_participant_status = mine?.status ?? null;

  return json;
}

/**
 * What state is this game in, right now?
 *
 * Derived rather than stored so a game cannot advertise itself as open after
 * its slot has been played. `in_progress` is deliberately distinct from
 * `completed`: a slot that started ten minutes ago can no longer be joined but
 * is not over, and telling a player "completed" while their game is running
 * reads as a bug.
 */
function derivedStatus(json, booking, seatedCount, seats) {
  if (json.is_active === false) return 'cancelled';
  if (!booking) return 'cancelled';
  if (booking.is_canceled || booking.status === 'cancelled') return 'cancelled';

  const { slot_date: date, slot_time_from: from, slot_time_to: to } = booking;
  if (date && from && to && isPastSlotEnd(date, from, to)) return 'completed';
  if (date && from && isPastSlot(date, from)) return 'in_progress';
  if (seats > 0 && seatedCount >= seats) return 'full';
  return 'open';
}

/** A game can only be joined or left while it is still open and unplayed. */
function isJoinable(payload) {
  return payload.status === 'open';
}


// ── Query building ───────────────────────────────────────────────────────────

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
 * What the host of a game may change about it.
 *
 * The same rule `utils/groundFields.js` and `utils/coachFields.js` hold their
 * owners to. `PUT /games/:id` used to spread `req.body` straight into
 * `Game.update`, so a host could re-point their game at somebody else's
 * `booking_id`, hand it to another `hosted_by_user_id`, or flip `is_active`
 * back on after it was cancelled — all of them columns on the model and none
 * of them theirs to set. Cancelling has its own endpoint, which notifies the
 * players; that is why `is_active` is deliberately absent here.
 */
const GAME_HOST_FIELDS = [
  'game_name', 'description', 'image', 'max_participants', 'game_level', 'visibility',
];

/** Take only the whitelisted keys that were actually sent. */
function pickGameFields(body, allowed = GAME_HOST_FIELDS) {
  const patch = {};
  for (const key of allowed) {
    if (body[key] !== undefined) patch[key] = body[key];
  }
  return patch;
}

/** Load one game with everything a payload needs. */
function findGameWhole(id, options = {}) {
  return Game.findByPk(id, {
    include: [HOST_INCLUDE, PARTICIPANTS_INCLUDE, BOOKING_INCLUDE],
    ...options,
  });
}

module.exports = {
  GAME_LEVELS,
  dateWindow,
  bookingWhere,
  GAME_HOST_FIELDS,
  pickGameFields,
  SEATED,
  BOOKING_INCLUDE,
  HOST_INCLUDE,
  PARTICIPANTS_INCLUDE,
  GAME_INCLUDES: [HOST_INCLUDE, PARTICIPANTS_INCLUDE, BOOKING_INCLUDE],
  serialize,
  derivedStatus,
  isJoinable,
  findGameWhole,
};
