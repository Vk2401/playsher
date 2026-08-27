const router = require('express').Router();
const ctrl = require('../controllers/game.controller');
const { verifyToken, requireRole, optionalAuth } = require('../middleware/auth');
const validate = require('../middleware/validate');
const {
  listGames, createGame, updateGame, gameId, inviteUsers, respondInvite,
} = require('../validators/game.validator');

/**
 * @swagger
 * tags:
 *   name: Games
 *   description: Open games — a booked slot with seats opened on it
 */

/**
 * @swagger
 * /games:
 *   get:
 *     tags: [Games]
 *     summary: The discovery feed — open games, soonest first
 *     description: >
 *       Public, but answers better with a token: when one is sent the payload
 *       marks `is_host`, `is_joined` and `my_participant_status` for the caller.
 *       Past games are hidden unless `include_past=true`.
 *     security: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *       - in: query
 *         name: sport_id
 *         schema: { type: integer }
 *       - in: query
 *         name: ground_id
 *         schema: { type: integer }
 *       - in: query
 *         name: city
 *         schema: { type: string }
 *       - in: query
 *         name: search
 *         description: Matches game name, description, ground name/area and sport
 *         schema: { type: string }
 *       - in: query
 *         name: level
 *         schema:
 *           type: string
 *           enum: [newbie, beginner, intermediate, advanced, professional, ultra_professional]
 *       - in: query
 *         name: when
 *         description: Date shorthand the app's chips send
 *         schema: { type: string, enum: [today, tomorrow, weekend, week] }
 *       - in: query
 *         name: date
 *         schema: { type: string, format: date }
 *       - in: query
 *         name: date_from
 *         schema: { type: string, format: date }
 *       - in: query
 *         name: date_to
 *         schema: { type: string, format: date }
 *       - in: query
 *         name: only_open
 *         description: Drop games that are full, started or cancelled
 *         schema: { type: boolean }
 *       - in: query
 *         name: exclude_mine
 *         description: Drop games the caller hosts or has already joined
 *         schema: { type: boolean }
 *       - in: query
 *         name: sort
 *         schema: { type: string, enum: [soonest, latest, newest], default: soonest }
 *       - in: query
 *         name: visibility
 *         description: '`private` lists only the caller''s own invite-only games'
 *         schema: { type: string, enum: [public, private] }
 *     responses:
 *       200: { description: Games list }
 */
router.get('/', optionalAuth, listGames, validate, ctrl.list);

/**
 * @swagger
 * /games/mine:
 *   get:
 *     tags: [Games]
 *     summary: Games I host and games I have joined (user)
 *     description: >
 *       One list, each row carrying `relation` = `hosting` | `playing`. Past
 *       games are included — this list is also the player's archive.
 *     parameters:
 *       - in: query
 *         name: scope
 *         description: >
 *           `upcoming` (default, soonest first), `past` (most recent first),
 *           or `all`.
 *         schema: { type: string, enum: [upcoming, past, all], default: upcoming }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: The caller's games }
 */
router.get('/mine', verifyToken, requireRole('user'), listGames, validate, ctrl.mine);

/**
 * @swagger
 * /games/{id}:
 *   get:
 *     tags: [Games]
 *     summary: Get a game by ID
 *     description: A private game answers 404 to anyone who is not its host or an invitee.
 *     security: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Game detail }
 *       404: { description: Not found }
 */
router.get('/:id', optionalAuth, gameId, validate, ctrl.show);

/**
 * @swagger
 * /games:
 *   post:
 *     tags: [Games]
 *     summary: Open seats on a slot you have already booked (user | ground_owner)
 *     description: >
 *       The booking must be the caller's own (a ground owner may host on a
 *       booking at their own ground), unplayed, not cancelled, and must not
 *       already carry a game. The host is written in as a participant, so the
 *       fill count includes them from the start.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [game_name, booking_id]
 *             properties:
 *               game_name:        { type: string }
 *               booking_id:       { type: integer }
 *               max_participants: { type: integer, minimum: 2, maximum: 50, default: 10 }
 *               game_level:       { type: string }
 *               visibility:       { type: string, enum: [public, private] }
 *               description:      { type: string }
 *     responses:
 *       201: { description: Game created }
 *       403: { description: Not your booking }
 *       404: { description: Booking not found }
 *       409: { description: Booking cancelled, already played, or already hosting a game }
 */
router.post('/', verifyToken, requireRole('user', 'ground_owner'), createGame, validate, ctrl.create);

/**
 * @swagger
 * /games/{id}:
 *   put:
 *     tags: [Games]
 *     summary: Update a game (host | admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               game_name:        { type: string }
 *               max_participants: { type: integer, minimum: 2, maximum: 50 }
 *               game_level:       { type: string }
 *               visibility:       { type: string, enum: [public, private] }
 *               description:      { type: string }
 *     responses:
 *       200: { description: Updated }
 *       403: { description: Not authorized }
 *       404: { description: Not found }
 *       409: { description: Limit set below the seats already taken }
 */
router.put('/:id', verifyToken, requireRole('user', 'ground_owner', 'admin'), updateGame, validate, ctrl.update);

/**
 * @swagger
 * /games/{id}/cancel:
 *   patch:
 *     tags: [Games]
 *     summary: Call the game off, keeping the booking (host | admin)
 *     description: >
 *       Closes the game and notifies everyone who joined. The slot stays booked
 *       and paid for — cancelling the booking is a separate action.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Cancelled }
 *       403: { description: Not authorized }
 *       404: { description: Not found }
 *       409: { description: Already cancelled }
 */
router.patch('/:id/cancel', verifyToken, requireRole('user', 'ground_owner', 'admin'), gameId, validate, ctrl.cancel);

/**
 * @swagger
 * /games/{id}:
 *   delete:
 *     tags: [Games]
 *     summary: Delete a game (host | admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 *       403: { description: Not authorized }
 *       404: { description: Not found }
 */
router.delete('/:id', verifyToken, requireRole('user', 'ground_owner', 'admin'), gameId, validate, ctrl.destroy);

/**
 * @swagger
 * /games/{id}/join:
 *   post:
 *     tags: [Games]
 *     summary: Take one of the open seats (user)
 *     description: >
 *       Serialised behind a row lock, so two players tapping the last seat at
 *       once cannot both get it. The host is notified.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Joined — the full game is returned }
 *       403: { description: Invite-only game }
 *       404: { description: Not found }
 *       409: { description: Full, already joined, hosting, started or cancelled }
 */
router.post('/:id/join', verifyToken, requireRole('user'), gameId, validate, ctrl.join);

/**
 * @swagger
 * /games/{id}/leave:
 *   delete:
 *     tags: [Games]
 *     summary: Give the seat back (user)
 *     description: A host cannot leave their own game — they cancel it instead.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Left game }
 *       404: { description: Not in this game }
 *       409: { description: You are the host }
 */
router.delete('/:id/leave', verifyToken, requireRole('user'), gameId, validate, ctrl.leave);

/**
 * @swagger
 * /games/{id}/invite:
 *   post:
 *     tags: [Games]
 *     summary: Invite players to a game (host)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [user_ids]
 *             properties:
 *               user_ids:
 *                 type: array
 *                 items: { type: integer }
 *                 example: [2, 5, 9]
 *     responses:
 *       200: { description: Invitations sent }
 */
router.post('/:id/invite', verifyToken, requireRole('user', 'ground_owner'), inviteUsers, validate, ctrl.invite);

/**
 * @swagger
 * /games/{id}/invite/{userId}/respond:
 *   patch:
 *     tags: [Games]
 *     summary: Respond to a game invitation (user)
 *     description: Accepting goes through the same capacity gate as joining.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: userId
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [status]
 *             properties:
 *               status: { type: string, enum: [accepted, declined] }
 *     responses:
 *       200: { description: Response recorded }
 *       404: { description: Invitation not found }
 *       409: { description: Game filled up or is no longer open }
 */
router.patch('/:id/invite/:userId/respond', verifyToken, requireRole('user'), respondInvite, validate, ctrl.respondInvite);

module.exports = router;
