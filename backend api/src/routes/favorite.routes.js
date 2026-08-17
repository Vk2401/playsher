const router = require('express').Router();
const ctrl = require('../controllers/favorite.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const { body } = require('express-validator');
const validate = require('../middleware/validate');

/**
 * @swagger
 * tags:
 *   name: Favorites
 *   description: User favorite grounds
 */

/**
 * @swagger
 * /favorites:
 *   get:
 *     tags: [Favorites]
 *     summary: Get own favorites (user)
 *     responses:
 *       200: { description: Favorites list }
 */
router.get('/', verifyToken, requireRole('user'), ctrl.list);

/**
 * @swagger
 * /favorites:
 *   post:
 *     tags: [Favorites]
 *     summary: Add a ground to favorites (user)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [ground_id]
 *             properties:
 *               ground_id: { type: integer }
 *     responses:
 *       201: { description: Added to favorites }
 */
router.post(
  '/',
  verifyToken,
  requireRole('user'),
  [body('ground_id').isInt({ min: 1 }).withMessage('ground_id is required.')],
  validate,
  ctrl.add
);

/**
 * @swagger
 * /favorites/{groundId}:
 *   delete:
 *     tags: [Favorites]
 *     summary: Remove a ground from favorites (user)
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Removed }
 */
router.delete('/:groundId', verifyToken, requireRole('user'), ctrl.remove);

module.exports = router;
