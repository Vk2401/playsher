const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const ctrl = require('../controllers/player.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const {
  handleParam, searchPlayers, playerId,
} = require('../validators/player.validator');

/**
 * Looking people up is rate-limited, and search most of all.
 *
 * Lookup by phone number is exact-match only, which already stops the endpoint
 * being walked digit by digit — but a handle prefix search can still be swept
 * alphabetically to build a picture of the user base. A cap per window makes
 * that expensive without getting in the way of a person typing a name.
 */
const searchLimiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.SEARCH_RATE_LIMIT_MAX) || 120,
  message: { success: false, message: 'Too many searches. Please slow down and try again shortly.' },
});

/** Every route here is for a signed-in customer — profiles are not anonymous. */
const player = [verifyToken, requireRole('user')];

/**
 * @swagger
 * tags:
 *   name: Players
 *   description: >
 *     Public player profiles, the follow graph, and finding somebody to invite.
 *     Contact details are never returned — a mobile number can be used to find
 *     an account, but is not part of any response.
 */

/**
 * @swagger
 * /players/search:
 *   get:
 *     tags: [Players]
 *     summary: Find a player by username, name or exact mobile number
 *     description: >
 *       A value that parses as an Indian mobile number is matched **exactly**
 *       and only exactly — there is no prefix or partial match on a phone
 *       number, so this endpoint cannot be used to enumerate accounts. Anything
 *       else is matched against the username (prefix first) and the display
 *       name. The caller is never in their own results, and no result carries a
 *       mobile number or email.
 *     parameters:
 *       - in: query
 *         name: q
 *         required: true
 *         schema: { type: string, minLength: 2 }
 *         description: A username, a display name, or a full mobile number
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Matching players }
 *       400: { description: Query too short }
 *       429: { description: Too many searches }
 */
router.get('/search', ...player, searchLimiter, searchPlayers, validate, ctrl.search);

/**
 * @swagger
 * /players/teammates:
 *   get:
 *     tags: [Players]
 *     summary: Players I have shared a game with, most-played first
 *     description: >
 *       The default list in the invite sheet: the people most likely to be
 *       invited to your next game are the ones who were in your last one.
 *     responses:
 *       200: { description: Teammates, ordered by games shared }
 */
router.get('/teammates', ...player, ctrl.teammates);

/**
 * @swagger
 * /players/{handle}:
 *   get:
 *     tags: [Players]
 *     summary: A player's public profile
 *     description: >
 *       `handle` is either a username or a numeric user id — a client links by
 *       whichever it holds. No contact details are returned.
 *     parameters:
 *       - in: path
 *         name: handle
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Public profile with follow counts and game stats }
 *       404: { description: No such player }
 */
router.get('/:handle', ...player, handleParam, validate, ctrl.show);

/**
 * @swagger
 * /players/{handle}/games:
 *   get:
 *     tags: [Players]
 *     summary: The public games this player is in
 *     description: Private games are never listed — they are not the viewer's to see.
 *     parameters:
 *       - in: path
 *         name: handle
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Public games }
 *       404: { description: No such player }
 */
router.get('/:handle/games', ...player, handleParam, validate, ctrl.games);

/**
 * @swagger
 * /players/{handle}/followers:
 *   get:
 *     tags: [Players]
 *     summary: Who follows this player
 *     parameters:
 *       - in: path
 *         name: handle
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Follower list }
 *       404: { description: No such player }
 */
router.get('/:handle/followers', ...player, handleParam, validate, ctrl.followers);

/**
 * @swagger
 * /players/{handle}/following:
 *   get:
 *     tags: [Players]
 *     summary: Who this player follows
 *     parameters:
 *       - in: path
 *         name: handle
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200: { description: Following list }
 *       404: { description: No such player }
 */
router.get('/:handle/following', ...player, handleParam, validate, ctrl.following);

/**
 * @swagger
 * /players/{id}/follow:
 *   post:
 *     tags: [Players]
 *     summary: Follow a player
 *     description: >
 *       Idempotent — following someone you already follow succeeds and sends no
 *       second notification. Following is one-directional and needs no consent
 *       from the other side.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Now following, with the updated follower count }
 *       404: { description: No such player }
 *       409: { description: You cannot follow yourself }
 */
router.post('/:id/follow', ...player, playerId, validate, ctrl.follow);

/**
 * @swagger
 * /players/{id}/follow:
 *   delete:
 *     tags: [Players]
 *     summary: Unfollow a player
 *     description: Idempotent — unfollowing someone you do not follow is the state you asked for.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: No longer following }
 */
router.delete('/:id/follow', ...player, playerId, validate, ctrl.unfollow);

module.exports = router;
