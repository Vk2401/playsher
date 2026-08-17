const router = require('express').Router();
const ctrl = require('../controllers/groundOwner.controller');
const { verifyToken, requireRole } = require('../middleware/auth');

/**
 * @swagger
 * tags:
 *   name: GroundOwners
 *   description: Ground owner management (admin)
 */

/**
 * @swagger
 * /ground-owners:
 *   get:
 *     tags: [GroundOwners]
 *     summary: List all ground owners (admin)
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
 *         description: Search by name or email
 *       - in: query
 *         name: is_approved
 *         schema: { type: boolean }
 *     responses:
 *       200: { description: Paginated ground owner list }
 */
router.get('/', verifyToken, requireRole('admin'), ctrl.list);

/**
 * @swagger
 * /ground-owners/{id}:
 *   get:
 *     tags: [GroundOwners]
 *     summary: Get ground owner by ID (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground owner detail }
 *       404: { description: Not found }
 */
router.get('/:id', verifyToken, requireRole('admin'), ctrl.show);

/**
 * @swagger
 * /ground-owners/{id}/approve:
 *   patch:
 *     tags: [GroundOwners]
 *     summary: Approve a ground owner's registration (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground owner approved }
 *       404: { description: Not found }
 */
router.patch('/:id/approve', verifyToken, requireRole('admin'), ctrl.approve);

/**
 * @swagger
 * /ground-owners/{id}/toggle-status:
 *   patch:
 *     tags: [GroundOwners]
 *     summary: Toggle ground owner active/inactive status (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Status toggled }
 */
router.patch('/:id/toggle-status', verifyToken, requireRole('admin'), ctrl.toggleStatus);

/**
 * @swagger
 * /ground-owners/{id}:
 *   delete:
 *     tags: [GroundOwners]
 *     summary: Delete a ground owner (admin)
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

module.exports = router;
