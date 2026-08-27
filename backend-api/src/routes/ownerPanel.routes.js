/**
 * Ground Owner Panel Routes — mounted at /api/v1/ground-owner
 * All routes require ground_owner role.
 */

/**
 * @swagger
 * tags:
 *   name: OwnerPanel
 *   description: Ground owner panel — manage own grounds, slots, bookings and games (requires ground_owner role)
 */

const router = require('express').Router();
const { verifyToken, requireRole } = require('../middleware/auth');
const { uploadGround, uploadGroundImg } = require('../middleware/upload');
const op = require('../controllers/ownerPanel.controller');
const schedule = require('../controllers/schedule.controller');
const validate = require('../middleware/validate');
const { updateOwnerGroundSport } = require('../validators/ground.validator');

const owner = [verifyToken, requireRole('ground_owner')];

// ── Grounds ───────────────────────────────────────────────────────────────────

/**
 * @swagger
 * /ground-owner/grounds:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: List own grounds
 *     responses:
 *       200: { description: List of owner's grounds }
 */
router.get   ('/grounds',                    ...owner, op.listGrounds);
/**
 * @swagger
 * /ground-owner/grounds/{id}:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: Get a specific own ground by ID
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground detail }
 *       403: { description: Not your ground }
 *       404: { description: Not found }
 */
router.get   ('/grounds/:id',                ...owner, op.getGround);

/**
 * @swagger
 * /ground-owner/grounds:
 *   post:
 *     tags: [OwnerPanel]
 *     summary: Create a new ground
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [name]
 *             properties:
 *               name:        { type: string }
 *               about:       { type: string }
 *               description: { type: string }
 *               address:     { type: string }
 *               latitude:    { type: number }
 *               longitude:   { type: number }
 *               venue_rules: { type: string }
 *               cover_image: { type: string, format: binary }
 *     responses:
 *       201: { description: Ground created (pending approval) }
 */
router.post  ('/grounds',                    ...owner, uploadGround, op.createGround);

/**
 * @swagger
 * /ground-owner/grounds/{id}:
 *   put:
 *     tags: [OwnerPanel]
 *     summary: Update own ground
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
 *               name:        { type: string }
 *               about:       { type: string }
 *               description: { type: string }
 *               address:     { type: string }
 *               venue_rules: { type: string }
 *     responses:
 *       200: { description: Updated }
 */
router.put   ('/grounds/:id',                ...owner, op.updateGround);

/**
 * @swagger
 * /ground-owner/grounds/{id}:
 *   delete:
 *     tags: [OwnerPanel]
 *     summary: Delete own ground (no active bookings)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/grounds/:id',                ...owner, op.deleteGround);

// Ground Images
/**
 * @swagger
 * /ground-owner/grounds/{id}/images:
 *   post:
 *     tags: [OwnerPanel]
 *     summary: Upload images for a ground
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               images:
 *                 type: array
 *                 items: { type: string, format: binary }
 *     responses:
 *       201: { description: Images uploaded }
 */
router.post  ('/grounds/:id/images',              ...owner, uploadGroundImg, op.addImage);

/**
 * @swagger
 * /ground-owner/grounds/{id}/images/{imageId}:
 *   delete:
 *     tags: [OwnerPanel]
 *     summary: Remove a ground image
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: imageId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Image removed }
 */
router.delete('/grounds/:id/images/:imageId',     ...owner, op.deleteImage);

// Ground Amenities (mapping)
/**
 * @swagger
 * /ground-owner/grounds/{id}/amenities:
 *   post:
 *     tags: [OwnerPanel]
 *     summary: Attach amenities to a ground
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
 *               amenity_ids: { type: array, items: { type: integer } }
 *     responses:
 *       200: { description: Amenities attached }
 */
router.post  ('/grounds/:id/amenities',           ...owner, op.addAmenity);

/**
 * @swagger
 * /ground-owner/grounds/{id}/amenities/{amenityId}:
 *   delete:
 *     tags: [OwnerPanel]
 *     summary: Remove an amenity from a ground
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: amenityId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Amenity removed }
 */
router.delete('/grounds/:id/amenities/:amenityId', ...owner, op.removeAmenity);

// Ground Sports (mapping / ground_sports)
/**
 * @swagger
 * /ground-owner/grounds/{id}/sports:
 *   post:
 *     tags: [OwnerPanel]
 *     summary: Add a sport to a ground
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
 *             required: [sport_id, price_per_slot]
 *             properties:
 *               sport_id:       { type: integer }
 *               price_per_slot: { type: number }
 *               slot_duration:  { type: integer, example: 60 }
 *               max_players:    { type: integer }
 *     responses:
 *       201: { description: Sport added to ground }
 */
router.post  ('/grounds/:id/sports',              ...owner, op.addSport);

/**
 * @swagger
 * /ground-owner/grounds/{id}/sports/{sportId}:
 *   put:
 *     tags: [OwnerPanel]
 *     summary: Update a ground's sport settings (price, slot limits, availability)
 *     description: >
 *       sportId is the ground_sport row id, not the sport id. The sport itself
 *       cannot be changed here — remove the row and add the other sport instead.
 *       Note that removing a row cascades away its schedule and slots.
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: sportId
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               # The column name is historical; a slot is 30 minutes and
 *               # every human-facing surface calls this the price per slot.
 *               min_slots:           { type: integer }
 *               max_slots:           { type: integer }
 *               player_counts:       { type: string }
 *               cancellation_policy: { type: string }
 *               is_active:           { type: boolean }
 *     responses:
 *       200: { description: Sport updated }
 *       404: { description: Ground or ground sport not found }
 *       422: { description: Validation failed }
 */
router.put   ('/grounds/:id/sports/:sportId',     ...owner, updateOwnerGroundSport, validate, op.updateSport);

/**
 * @swagger
 * /ground-owner/grounds/{id}/sports/{sportId}:
 *   delete:
 *     tags: [OwnerPanel]
 *     summary: Remove a sport from a ground
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: sportId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Sport removed }
 */
router.delete('/grounds/:id/sports/:sportId',     ...owner, op.removeSport);

// Slots (nested under ground)
/**
 * @swagger
 * /ground-owner/grounds/{groundId}/slots:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: List all slots for a ground
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *       - in: query
 *         name: date
 *         schema: { type: string, format: date }
 *     responses:
 *       200: { description: Slots list }
 */
router.get   ('/grounds/:groundId/slots',                          ...owner, op.listSlots);

/**
 * @swagger
 * /ground-owner/grounds/{groundId}/slots:
 *   post:
 *     tags: [OwnerPanel]
 *     summary: Create a slot for a ground sport
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
 *             required: [ground_sport_id, start_time, end_time, day_of_week]
 *             properties:
 *               ground_sport_id: { type: integer }
 *               start_time:      { type: string, example: '08:00' }
 *               end_time:        { type: string, example: '09:00' }
 *               day_of_week:     { type: integer, minimum: 0, maximum: 6 }
 *               is_available:    { type: boolean, default: true }
 *     responses:
 *       201: { description: Slot created }
 */
router.post  ('/grounds/:groundId/slots',                          ...owner, op.createSlot);

/**
 * @swagger
 * /ground-owner/grounds/{groundId}/slots/{slotId}:
 *   put:
 *     tags: [OwnerPanel]
 *     summary: Update a slot
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: slotId
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               start_time:   { type: string }
 *               end_time:     { type: string }
 *               is_available: { type: boolean }
 *     responses:
 *       200: { description: Updated }
 */
router.put   ('/grounds/:groundId/slots/:slotId',                  ...owner, op.updateSlot);

/**
 * @swagger
 * /ground-owner/grounds/{groundId}/slots/{slotId}:
 *   delete:
 *     tags: [OwnerPanel]
 *     summary: Delete a slot
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: slotId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/grounds/:groundId/slots/:slotId',                  ...owner, op.deleteSlot);

/**
 * @swagger
 * /ground-owner/grounds/{groundId}/slots/{slotId}/toggle:
 *   patch:
 *     tags: [OwnerPanel]
 *     summary: Toggle slot availability
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: slotId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Availability toggled }
 */
router.patch ('/grounds/:groundId/slots/:slotId/toggle',           ...owner, op.toggleSlot);

// ── Schedule Templates ────────────────────────────────────────────────────────
/**
 * @swagger
 * /ground-owner/grounds/{groundId}/schedule:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: Get weekly schedule templates for a ground
 *     parameters:
 *       - in: path
 *         name: groundId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Schedule templates for each ground sport }
 */
router.get   ('/grounds/:groundId/schedule',  ...owner, schedule.list);

/**
 * @swagger
 * /ground-owner/grounds/{groundId}/schedule:
 *   put:
 *     tags: [OwnerPanel]
 *     summary: Upsert weekly schedule for a ground sport
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
 *             required: [ground_sport_id, schedules]
 *             properties:
 *               ground_sport_id: { type: integer }
 *               schedules:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     day_of_week: { type: integer, minimum: 0, maximum: 6 }
 *                     start_time:  { type: string, example: '06:00:00' }
 *                     end_time:    { type: string, example: '22:00:00' }
 *                     is_closed:   { type: boolean }
 *     responses:
 *       200: { description: Schedule saved }
 */
router.put   ('/grounds/:groundId/schedule',  ...owner, schedule.upsert);

// ── Bookings ──────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /ground-owner/bookings:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: List all bookings on own grounds
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, confirmed, cancelled, completed] }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Bookings list }
 */
router.get   ('/bookings',          ...owner, op.listBookings);

/**
 * @swagger
 * /ground-owner/bookings/{id}:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: Get a specific booking on own ground
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Booking detail }
 *       403: { description: Not your booking }
 *       404: { description: Not found }
 */
router.get   ('/bookings/:id',      ...owner, op.getBooking);

/**
 * @swagger
 * /ground-owner/bookings/{id}/cancel:
 *   patch:
 *     tags: [OwnerPanel]
 *     summary: Cancel a booking on own ground
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
 *               cancellation_reason: { type: string }
 *     responses:
 *       200: { description: Booking cancelled }
 */
router.patch ('/bookings/:id/cancel', ...owner, op.cancelBooking);

// ── Games ─────────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /ground-owner/games:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: List open games running at my grounds
 *     description: >
 *       Scoped by venue, not by who published the game — nearly every game is
 *       opened by a customer on their own booking. Rows carry the venue, the
 *       schedule, the seats taken and the derived status.
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *       - in: query
 *         name: visibility
 *         schema: { type: string, enum: [public, private] }
 *     responses:
 *       200: { description: Games list }
 */
router.get('/games', ...owner, op.listGames);



// ── Coaches at my grounds ─────────────────────────────────────────────────────

/**
 * @swagger
 * /ground-owner/coach-requests:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: Coaches asking to work at my grounds
 *     description: Unanswered requests are listed first.
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, approved, rejected] }
 *     responses:
 *       200: { description: Coach registration requests }
 */
router.get   ('/coach-requests',              ...owner, op.listCoachRequests);

/**
 * @swagger
 * /ground-owner/coach-requests/{id}/approve:
 *   patch:
 *     tags: [OwnerPanel]
 *     summary: Let a coach work at my ground
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
 *               response_note: { type: string }
 *     responses:
 *       200: { description: Approved — players can now book this coach here }
 *       404: { description: Not a request on one of your grounds }
 *       409: { description: Already approved }
 */
router.patch ('/coach-requests/:id/approve',  ...owner, op.approveCoachRequest);

/**
 * @swagger
 * /ground-owner/coach-requests/{id}/reject:
 *   patch:
 *     tags: [OwnerPanel]
 *     summary: Decline a coach's registration at my ground
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
 *               response_note: { type: string }
 *     responses:
 *       200: { description: Declined }
 *       404: { description: Not a request on one of your grounds }
 *       409: { description: Already declined, or sessions still upcoming }
 */
router.patch ('/coach-requests/:id/reject',   ...owner, op.rejectCoachRequest);

/**
 * @swagger
 * /ground-owner/coaches:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: Coaches approved to work at my grounds
 *     responses:
 *       200: { description: Approved coach registrations }
 */
router.get   ('/coaches',                     ...owner, op.listGroundCoaches);

/**
 * @swagger
 * /ground-owner/coach-sessions:
 *   get:
 *     tags: [OwnerPanel]
 *     summary: Coaching sessions taking place at my grounds
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, confirmed, rejected, cancelled, completed] }
 *       - in: query
 *         name: upcoming
 *         schema: { type: string, enum: ['true'] }
 *       - in: query
 *         name: date
 *         schema: { type: string, format: date }
 *     responses:
 *       200: { description: Coaching sessions on this owner's courts }
 */
router.get   ('/coach-sessions',              ...owner, op.listCoachSessions);

module.exports = router;
