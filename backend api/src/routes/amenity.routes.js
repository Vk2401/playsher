const router = require('express').Router();
const ctrl = require('../controllers/amenity.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { createAmenity, updateAmenity } = require('../validators/amenity.validator');

/**
 * @swagger
 * tags:
 *   name: Amenities
 *   description: Amenity management
 */

/**
 * @swagger
 * /amenities:
 *   get:
 *     tags: [Amenities]
 *     summary: List amenities (public)
 *     security: []
 *     parameters:
 *       - in: query
 *         name: type
 *         schema: { type: string, enum: [venue, sport] }
 *     responses:
 *       200: { description: List of amenities }
 */
router.get('/', ctrl.list);

/**
 * @swagger
 * /amenities/{id}:
 *   get:
 *     tags: [Amenities]
 *     summary: Get amenity by ID (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Amenity }
 *       404: { description: Not found }
 */
router.get('/:id', ctrl.show);

/**
 * @swagger
 * /amenities:
 *   post:
 *     tags: [Amenities]
 *     summary: Create an amenity (admin)
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [name, type]
 *             properties:
 *               name:  { type: string, example: 'Parking' }
 *               type:  { type: string, enum: [venue, sport] }
 *               icon:  { type: string, format: binary, description: Icon image file }
 *     responses:
 *       201: { description: Amenity created }
 *       400: { description: Validation error }
 */
router.post('/', verifyToken, requireRole('admin'), createAmenity, validate, ctrl.create);

/**
 * @swagger
 * /amenities/{id}:
 *   put:
 *     tags: [Amenities]
 *     summary: Update an amenity (admin)
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
 *               name: { type: string }
 *               type: { type: string, enum: [venue, sport] }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 */
router.put('/:id', verifyToken, requireRole('admin'), updateAmenity, validate, ctrl.update);

/**
 * @swagger
 * /amenities/{id}:
 *   delete:
 *     tags: [Amenities]
 *     summary: Delete an amenity (admin)
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
