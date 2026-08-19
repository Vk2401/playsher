const router = require('express').Router();
const ctrl = require('../controllers/ground.controller');
const gsCtrl = require('../controllers/groundSport.controller');
const { verifyToken, requireRole } = require('../middleware/auth');
const validate = require('../middleware/validate');
const { createGround, updateGround, addAmenities, createGroundSport, updateGroundSport } = require('../validators/ground.validator');

/**
 * @swagger
 * tags:
 *   name: Grounds
 *   description: Ground management
 */

/**
 * @swagger
 * /grounds:
 *   get:
 *     tags: [Grounds]
 *     summary: List approved grounds (public)
 *     security: []
 *     parameters:
 *       - in: query
 *         name: sport_id
 *         schema: { type: integer }
 *       - in: query
 *         name: lat
 *         schema: { type: number }
 *       - in: query
 *         name: lng
 *         schema: { type: number }
 *       - in: query
 *         name: radius_km
 *         schema: { type: number }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: List of grounds }
 */
router.get('/', ctrl.list);

/**
 * @swagger
 * /grounds/{id}:
 *   get:
 *     tags: [Grounds]
 *     summary: Get a ground by ID (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground detail }
 *       404: { description: Not found }
 */
router.get('/:id', ctrl.show);

/**
 * @swagger
 * /grounds:
 *   post:
 *     tags: [Grounds]
 *     summary: Create a ground (ground_owner)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name]
 *             properties:
 *               name:        { type: string }
 *               about:       { type: string }
 *               description: { type: string }
 *               latitude:    { type: number }
 *               longitude:   { type: number }
 *               address:     { type: string }
 *               venue_rules: { type: string }
 *     responses:
 *       201: { description: Ground created }
 */
router.post('/', verifyToken, requireRole('ground_owner', 'admin'), createGround, validate, ctrl.create);

/**
 * @swagger
 * /grounds/{id}:
 *   put:
 *     tags: [Grounds]
 *     summary: Update a ground (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Updated }
 */
router.put('/:id', verifyToken, requireRole('ground_owner', 'admin'), updateGround, validate, ctrl.update);

/**
 * @swagger
 * /grounds/{id}:
 *   delete:
 *     tags: [Grounds]
 *     summary: Soft-delete a ground (admin | owner with no active bookings)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/:id', verifyToken, requireRole('ground_owner', 'admin'), ctrl.destroy);

/**
 * @swagger
 * /grounds/{id}/approve:
 *   patch:
 *     tags: [Grounds]
 *     summary: Approve a ground (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Approved }
 */
router.patch('/:id/approve', verifyToken, requireRole('admin'), ctrl.approve);

/**
 * @swagger
 * /grounds/{id}/toggle-status:
 *   patch:
 *     tags: [Grounds]
 *     summary: Toggle active status (admin)
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
 * /grounds/{id}/images:
 *   post:
 *     tags: [Grounds]
 *     summary: Add images to a ground (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               images:
 *                 type: array
 *                 items: { type: string, format: binary }
 *     responses:
 *       201: { description: Images added }
 */
router.post('/:id/images', verifyToken, requireRole('ground_owner', 'admin'), ctrl.addImages);

/**
 * @swagger
 * /grounds/{id}/images/{imgId}:
 *   delete:
 *     tags: [Grounds]
 *     summary: Remove an image from a ground (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: imgId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Image removed }
 *       404: { description: Image not found }
 */
router.delete('/:id/images/:imgId', verifyToken, requireRole('ground_owner', 'admin'), ctrl.removeImage);

/**
 * @swagger
 * /grounds/{id}/amenities:
 *   post:
 *     tags: [Grounds]
 *     summary: Attach amenities to a ground (ground_owner | admin)
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
 *             required: [amenity_ids]
 *             properties:
 *               amenity_ids:
 *                 type: array
 *                 items: { type: integer }
 *                 example: [1, 2, 3]
 *     responses:
 *       200: { description: Amenities attached }
 */
router.post('/:id/amenities', verifyToken, requireRole('ground_owner', 'admin'), addAmenities, validate, ctrl.addAmenities);

/**
 * @swagger
 * /grounds/{id}/amenities/{aId}:
 *   delete:
 *     tags: [Grounds]
 *     summary: Remove an amenity from a ground (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: aId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Amenity removed }
 */
router.delete('/:id/amenities/:aId', verifyToken, requireRole('ground_owner', 'admin'), ctrl.removeAmenity);

// Ground Sports (nested)
/**
 * @swagger
 * /grounds/{groundId}/sports:
 *   get:
 *     tags: [Grounds]
 *     summary: List sports for a ground (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground sports list }
 */
router.get('/:groundId/sports', gsCtrl.list);

/**
 * @swagger
 * /grounds/{groundId}/sports/{id}:
 *   get:
 *     tags: [Grounds]
 *     summary: Get a single ground sport by ID (public)
 *     security: []
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground sport detail }
 *       404: { description: Not found }
 */
router.get('/:groundId/sports/:id', gsCtrl.show);

/**
 * @swagger
 * /grounds/{groundId}/sports:
 *   post:
 *     tags: [Grounds]
 *     summary: Add a sport to a ground (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [sport_id, price_per_slot]
 *             properties:
 *               sport_id:       { type: integer }
 *               price_per_slot: { type: number, example: 500 }
 *               slot_duration:  { type: integer, example: 60, description: Duration in minutes }
 *               max_players:    { type: integer }
 *     responses:
 *       201: { description: Ground sport created }
 */
router.post('/:groundId/sports', verifyToken, requireRole('ground_owner', 'admin'), createGroundSport, validate, gsCtrl.create);

/**
 * @swagger
 * /grounds/{groundId}/sports/{id}:
 *   put:
 *     tags: [Grounds]
 *     summary: Update a ground sport (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
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
 *               price_per_slot: { type: number }
 *               slot_duration:  { type: integer }
 *               max_players:    { type: integer }
 *               is_active:      { type: boolean }
 *     responses:
 *       200: { description: Updated }
 */
router.put('/:groundId/sports/:id', verifyToken, requireRole('ground_owner', 'admin'), updateGroundSport, validate, gsCtrl.update);

/**
 * @swagger
 * /grounds/{groundId}/sports/{id}:
 *   delete:
 *     tags: [Grounds]
 *     summary: Remove a sport from a ground (ground_owner | admin)
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/:groundId/sports/:id', verifyToken, requireRole('ground_owner', 'admin'), gsCtrl.destroy);

module.exports = router;
