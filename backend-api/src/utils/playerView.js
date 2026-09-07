/**
 * What one player looks like to another.
 *
 * The same role `gameView` plays for games: one place that decides the shape,
 * so the profile screen, a search result, a follower list and a game's squad
 * cannot disagree about who somebody is.
 *
 * **The rule that matters here is what is left out.** A player profile is
 * visible to any signed-in player, including strangers a game just introduced
 * them to. `mobile` and `email` therefore never appear in anything this module
 * emits — not in a search result, not on a profile, not on a participant row.
 * A phone number is how an account is *found* by someone who already has it
 * (see the exact-match rule in `player.controller.search`); it is never
 * something the API hands back.
 */
const { Op } = require('sequelize');

/** Everything a public view of a player may select. Deliberately short. */
const PUBLIC_ATTRIBUTES = ['id', 'username', 'name', 'profile_picture', 'bio', 'created_at'];

/** The subset a card, a squad row or a search result needs. */
const CARD_ATTRIBUTES = ['id', 'username', 'name', 'profile_picture'];

/**
 * A player as a card: the smallest honest identity.
 *
 * Used wherever somebody appears beside something else — a game's squad, a
 * follower list, a search result.
 */
function toCard(user, { isFollowing = null, isSelf = false } = {}) {
  if (!user) return null;
  const json = typeof user.toJSON === 'function' ? user.toJSON() : user;

  return {
    id             : json.id,
    username       : json.username ?? null,
    name           : json.name ?? null,
    profile_picture: json.profile_picture ?? null,
    ...(isFollowing === null ? {} : { is_following: isFollowing }),
    ...(isSelf ? { is_self: true } : {}),
  };
}

/**
 * A player's full public profile.
 *
 * `stats` and the viewer's relationship are passed in rather than queried here,
 * because this module is pure — the controller does the counting, and this
 * decides only what is shown.
 */
function toProfile(user, {
  followers = 0,
  following = 0,
  gamesHosted = 0,
  gamesPlayed = 0,
  sports = [],
  isFollowing = false,
  followsYou = false,
  isSelf = false,
} = {}) {
  if (!user) return null;
  const json = typeof user.toJSON === 'function' ? user.toJSON() : user;

  return {
    id             : json.id,
    username       : json.username ?? null,
    name           : json.name ?? null,
    profile_picture: json.profile_picture ?? null,
    bio            : json.bio ?? null,
    member_since   : json.created_at ?? null,

    followers_count: followers,
    following_count: following,
    games_hosted   : gamesHosted,
    games_played   : gamesPlayed,

    // What the player is actually into, so a profile says something before
    // they have played a single game.
    sports,

    // The viewer's own relationship, which is what the follow button binds to.
    is_self     : isSelf,
    is_following: isFollowing,
    follows_you : followsYou,
  };
}

/**
 * Which of these user ids the viewer already follows.
 *
 * One query for a whole page rather than one per row — a search result or a
 * follower list would otherwise issue N follow checks to render N buttons.
 *
 * @returns {Promise<Set<number>>}
 */
async function followedIdsAmong(UserFollow, viewerId, candidateIds) {
  if (!viewerId || candidateIds.length === 0) return new Set();

  const rows = await UserFollow.findAll({
    where     : { follower_id: viewerId, following_id: { [Op.in]: candidateIds } },
    attributes: ['following_id'],
  });
  return new Set(rows.map((r) => r.following_id));
}

module.exports = {
  PUBLIC_ATTRIBUTES,
  CARD_ATTRIBUTES,
  toCard,
  toProfile,
  followedIdsAmong,
};
