const router = require('express').Router();
const ctrl = require('../controllers/game.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { createGame, updateGame, inviteUsers, respondInvite } = require('../validators/game.validator');

/**
 * @swagger
 * tags:
 *   name: Games
 *   description: Game management
 */

/**
 * @swagger
 * /games:
 *   get:
 *     tags: [Games]
 *     summary: List public games
 *     security: []
 *     parameters:
 *       - in: query
 *         name: visibility
 *         schema: { type: string, enum: [public, private] }
 *       - in: query
 *         name: ground_id
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Games list }
 */
router.get('/', ctrl.list);
/**
 * @swagger
 * /games/{id}:
 *   get:
 *     tags: [Games]
 *     summary: Get a game by ID (public)
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
router.get('/:id', ctrl.show);

/**
 * @swagger
 * /games:
 *   post:
 *     tags: [Games]
 *     summary: Create a game (user | ground_owner)
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
 *               max_participants: { type: integer }
 *               game_level:       { type: string }
 *               visibility:       { type: string, enum: [public, private] }
 *               description:      { type: string }
 *     responses:
 *       201: { description: Game created }
 */
router.post('/', verifyToken, requireRole('user', 'ground_owner'), createGame, validate, ctrl.create);

/**
 * @swagger
 * /games/{id}:
 *   put:
 *     tags: [Games]
 *     summary: Update a game (creator | ground_owner | admin)
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
 *               max_participants: { type: integer }
 *               game_level:       { type: string }
 *               visibility:       { type: string, enum: [public, private] }
 *               description:      { type: string }
 *     responses:
 *       200: { description: Updated }
 *       403: { description: Not authorized }
 *       404: { description: Not found }
 */
router.put('/:id', verifyToken, requireRole('user', 'ground_owner', 'admin'), updateGame, validate, ctrl.update);

/**
 * @swagger
 * /games/{id}:
 *   delete:
 *     tags: [Games]
 *     summary: Delete a game (creator | ground_owner | admin)
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
router.delete('/:id', verifyToken, requireRole('user', 'ground_owner', 'admin'), ctrl.destroy);

/**
 * @swagger
 * /games/{id}/join:
 *   post:
 *     tags: [Games]
 *     summary: Join a public game (user)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Joined game }
 *       400: { description: Game full or already joined }
 *       403: { description: Game is private }
 *       404: { description: Not found }
 */
router.post('/:id/join', verifyToken, requireRole('user'), ctrl.join);

/**
 * @swagger
 * /games/{id}/leave:
 *   delete:
 *     tags: [Games]
 *     summary: Leave a game (user)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Left game }
 *       404: { description: Not in this game }
 */
router.delete('/:id/leave', verifyToken, requireRole('user'), ctrl.leave);

/**
 * @swagger
 * /games/{id}/invite:
 *   post:
 *     tags: [Games]
 *     summary: Invite users to a game (creator | ground_owner)
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
 */
router.patch('/:id/invite/:userId/respond', verifyToken, requireRole('user'), respondInvite, validate, ctrl.respondInvite);

module.exports = router;
