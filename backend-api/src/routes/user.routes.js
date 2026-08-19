const router = require('express').Router();
const ctrl = require('../controllers/user.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { updateUser, updateProfile, addSportPreferences } = require('../validators/user.validator');

/**
 * @swagger
 * tags:
 *   name: Users
 *   description: User management (admin) and profile (user)
 */

/**
 * @swagger
 * /users:
 *   get:
 *     tags: [Users]
 *     summary: List all users (admin)
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *         description: Search by name, email, or mobile
 *     responses:
 *       200: { description: Paginated user list }
 *       401: { description: Unauthorized }
 */
router.get('/', verifyToken, requireRole('admin'), ctrl.list);

/**
 * @swagger
 * /users/{id}:
 *   get:
 *     tags: [Users]
 *     summary: Get user by ID (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: User detail }
 *       404: { description: Not found }
 */
router.get('/:id', verifyToken, requireRole('admin'), ctrl.show);

/**
 * @swagger
 * /users/{id}:
 *   put:
 *     tags: [Users]
 *     summary: Update a user (admin)
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
 *               name:   { type: string }
 *               email:  { type: string, format: email }
 *               mobile: { type: string }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 */
router.put('/:id', verifyToken, requireRole('admin'), updateUser, validate, ctrl.update);

/**
 * @swagger
 * /users/{id}:
 *   delete:
 *     tags: [Users]
 *     summary: Soft-delete a user (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 *       404: { description: Not found }
 */
router.delete('/:id', verifyToken, requireRole('admin'), ctrl.destroy);

/**
 * @swagger
 * /users/{id}/toggle-status:
 *   patch:
 *     tags: [Users]
 *     summary: Toggle user active/inactive status (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Status toggled }
 *       404: { description: Not found }
 */
router.patch('/:id/toggle-status', verifyToken, requireRole('admin'), ctrl.toggleStatus);

module.exports = router;
