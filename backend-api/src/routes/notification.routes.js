const router = require('express').Router();
const ctrl = require('../controllers/notification.controller');
const { verifyToken } = require('../middleware/auth');

/**
 * @swagger
 * tags:
 *   name: Notifications
 *   description: The signed-in account's inbox — same shape for customers, ground owners, coaches and admins
 */

/**
 * @swagger
 * /notifications:
 *   get:
 *     tags: [Notifications]
 *     summary: List my notifications, newest first
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *       - in: query
 *         name: unread
 *         schema: { type: string, enum: ['true'] }
 *         description: Return only unread rows
 *     responses:
 *       200: { description: Notification list }
 *       401: { description: Not authenticated }
 */
router.get('/', verifyToken, ctrl.list);

/**
 * @swagger
 * /notifications/unread-count:
 *   get:
 *     tags: [Notifications]
 *     summary: How many unread notifications I have
 *     responses:
 *       200: { description: "{ unread: number }" }
 */
router.get('/unread-count', verifyToken, ctrl.unreadCount);

/**
 * @swagger
 * /notifications/read-all:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark every unread notification of mine as read
 *     responses:
 *       200: { description: "{ updated: number }" }
 */
router.patch('/read-all', verifyToken, ctrl.markAllRead);

/**
 * @swagger
 * /notifications/{id}/read:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark one notification as read
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Marked as read }
 *       404: { description: Not found in my inbox }
 */
router.patch('/:id/read', verifyToken, ctrl.markRead);

/**
 * @swagger
 * /notifications/{id}:
 *   delete:
 *     tags: [Notifications]
 *     summary: Delete one of my notifications
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 *       404: { description: Not found in my inbox }
 */
router.delete('/:id', verifyToken, ctrl.destroy);

module.exports = router;
