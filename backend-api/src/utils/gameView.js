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
const {
  Game, GameParticipant, Booking, GroundSport, Ground, Sport, User,
} = require('../models');
const { isPastSlot, isPastSlotEnd } = require('./appTime');

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


/** Load one game with everything a payload needs. */
function findGameWhole(id, options = {}) {
  return Game.findByPk(id, {
    include: [HOST_INCLUDE, PARTICIPANTS_INCLUDE, BOOKING_INCLUDE],
    ...options,
  });
}

module.exports = {
  GAME_LEVELS,
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
