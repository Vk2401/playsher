/**
 * Admin Panel Routes  — mounted at /api/v1/admin
 * All routes require admin role.
 */

/**
 * @swagger
 * tags:
 *   name: AdminPanel
 *   description: Admin panel — full platform management (requires admin role)
 */

const router = require('express').Router();
const { verifyToken, requireRole } = require('../middleware/auth');
const {
  uploadSport, uploadAmenity, uploadCoach,
} = require('../middleware/upload');

// Reuse existing controllers
const groundCtrl      = require('../controllers/ground.controller');
const groundOwnerCtrl = require('../controllers/groundOwner.controller');
const userCtrl        = require('../controllers/user.controller');
const bookingCtrl     = require('../controllers/booking.controller');
const paymentCtrl     = require('../controllers/payment.controller');

// Admin-specific controllers
const ap = require('../controllers/adminPanel.controller');
const appVersionCtrl = require('../controllers/appVersion.controller');

const validate = require('../middleware/validate');
const { upsertVersion } = require('../validators/appVersion.validator');

const admin = [verifyToken, requireRole('admin')];

// ── Grounds ───────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/grounds:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all grounds (admin — includes unapproved)
 *     parameters:
 *       - in: query
 *         name: is_approved
 *         schema: { type: boolean }
 *       - in: query
 *         name: is_active
 *         schema: { type: boolean }
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Paginated grounds list }
 */
router.get   ('/grounds',               ...admin, ap.listGrounds);

/**
 * @swagger
 * /admin/grounds/{id}:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Get ground by ID (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground detail }
 *       404: { description: Not found }
 */
router.get   ('/grounds/:id',           ...admin, groundCtrl.show);

/**
 * @swagger
 * /admin/grounds/{id}/approve:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Approve a ground (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground approved }
 */
router.patch ('/grounds/:id/approve',   ...admin, groundCtrl.approve);

/**
 * @swagger
 * /admin/grounds/{id}/toggle-status:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Toggle ground active status (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Status toggled }
 */
router.patch ('/grounds/:id/toggle-status', ...admin, groundCtrl.toggleStatus);

/**
 * @swagger
 * /admin/grounds/{id}:
 *   delete:
 *     tags: [AdminPanel]
 *     summary: Delete a ground (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Ground deleted }
 */
router.delete('/grounds/:id',           ...admin, groundCtrl.destroy);

// ── Ground Owners ─────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/ground-owners:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all ground owners (admin)
 *     parameters:
 *       - in: query
 *         name: is_approved
 *         schema: { type: boolean }
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Paginated ground owners list }
 */
router.get   ('/ground-owners',                    ...admin, groundOwnerCtrl.list);

/**
 * @swagger
 * /admin/ground-owners:
 *   post:
 *     tags: [AdminPanel]
 *     summary: Create a ground owner account (admin)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, email, mobile, password]
 *             properties:
 *               name:     { type: string }
 *               email:    { type: string, format: email }
 *               mobile:   { type: string }
 *               password: { type: string, minLength: 6 }
 *     responses:
 *       201: { description: Ground owner created }
 */
router.post  ('/ground-owners',                    ...admin, ap.createGroundOwner);

/**
 * @swagger
 * /admin/ground-owners/{id}:
 *   get:
 *     tags: [AdminPanel]
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
router.get   ('/ground-owners/:id',                ...admin, groundOwnerCtrl.show);

/**
 * @swagger
 * /admin/ground-owners/{id}/approve:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Approve a ground owner (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Approved }
 */
router.patch ('/ground-owners/:id/approve',        ...admin, groundOwnerCtrl.approve);

/**
 * @swagger
 * /admin/ground-owners/{id}/toggle-status:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Toggle ground owner active status (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Status toggled }
 */
router.patch ('/ground-owners/:id/toggle-status',  ...admin, groundOwnerCtrl.toggleStatus);

/**
 * @swagger
 * /admin/ground-owners/{id}:
 *   delete:
 *     tags: [AdminPanel]
 *     summary: Delete a ground owner (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/ground-owners/:id',                ...admin, groundOwnerCtrl.destroy);

// ── Users ─────────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/users:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all users (admin)
 *     parameters:
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: is_active
 *         schema: { type: boolean }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Paginated user list }
 */
router.get   ('/users',                    ...admin, userCtrl.list);

/**
 * @swagger
 * /admin/users:
 *   post:
 *     tags: [AdminPanel]
 *     summary: Create a user account (admin)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, mobile, password]
 *             properties:
 *               name:     { type: string }
 *               mobile:   { type: string }
 *               email:    { type: string, format: email }
 *               password: { type: string, minLength: 6 }
 *     responses:
 *       201: { description: User created }
 */
router.post  ('/users',                    ...admin, ap.createUser);

/**
 * @swagger
 * /admin/users/{id}:
 *   get:
 *     tags: [AdminPanel]
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
router.get   ('/users/:id',                ...admin, userCtrl.show);

/**
 * @swagger
 * /admin/users/{id}/toggle-status:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Toggle user active/inactive (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Status toggled }
 */
router.patch ('/users/:id/toggle-status',  ...admin, userCtrl.toggleStatus);

/**
 * @swagger
 * /admin/users/{id}:
 *   delete:
 *     tags: [AdminPanel]
 *     summary: Soft-delete a user (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/users/:id',                ...admin, userCtrl.destroy);

// ── Sports ────────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/sports:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all sports (admin — includes unapproved)
 *     parameters:
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: is_approved
 *         schema: { type: boolean }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Paginated sports list }
 */
router.get   ('/sports',              ...admin, ap.listSports);

/**
 * @swagger
 * /admin/sports:
 *   post:
 *     tags: [AdminPanel]
 *     summary: Create a sport with icon upload (admin)
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [name]
 *             properties:
 *               name:              { type: string }
 *               short_description: { type: string }
 *               place_type:        { type: string, enum: [ground, court] }
 *               sports_type:       { type: string, enum: [indoor, outdoor] }
 *               icon:              { type: string, format: binary }
 *     responses:
 *       201: { description: Sport created }
 */
router.post  ('/sports',              ...admin, uploadSport,  ap.createSport);

/**
 * @swagger
 * /admin/sports/{id}:
 *   put:
 *     tags: [AdminPanel]
 *     summary: Update a sport (admin)
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
 *               name:              { type: string }
 *               short_description: { type: string }
 *               place_type:        { type: string, enum: [ground, court] }
 *               sports_type:       { type: string, enum: [indoor, outdoor] }
 *               icon:              { type: string, format: binary }
 *     responses:
 *       200: { description: Updated }
 */
router.put   ('/sports/:id',          ...admin, uploadSport,  ap.updateSport);

/**
 * @swagger
 * /admin/sports/{id}/approve:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Approve a sport (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Approved }
 */
router.patch ('/sports/:id/approve',  ...admin, ap.approveSport);

/**
 * @swagger
 * /admin/sports/{id}:
 *   delete:
 *     tags: [AdminPanel]
 *     summary: Delete a sport (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/sports/:id',          ...admin, ap.deleteSport);

// ── Amenities ─────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/amenities:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all amenities (admin)
 *     parameters:
 *       - in: query
 *         name: type
 *         schema: { type: string, enum: [venue, sport] }
 *     responses:
 *       200: { description: Amenities list }
 */
router.get   ('/amenities',      ...admin, ap.listAmenities);

/**
 * @swagger
 * /admin/amenities:
 *   post:
 *     tags: [AdminPanel]
 *     summary: Create an amenity with icon upload (admin)
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [name, type]
 *             properties:
 *               name: { type: string }
 *               type: { type: string, enum: [venue, sport] }
 *               icon: { type: string, format: binary }
 *     responses:
 *       201: { description: Amenity created }
 */
router.post  ('/amenities',      ...admin, uploadAmenity, ap.createAmenity);

/**
 * @swagger
 * /admin/amenities/{id}:
 *   put:
 *     tags: [AdminPanel]
 *     summary: Update an amenity (admin)
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
 *               name: { type: string }
 *               type: { type: string, enum: [venue, sport] }
 *               icon: { type: string, format: binary }
 *     responses:
 *       200: { description: Updated }
 */
router.put   ('/amenities/:id',  ...admin, uploadAmenity, ap.updateAmenity);

/**
 * @swagger
 * /admin/amenities/{id}:
 *   delete:
 *     tags: [AdminPanel]
 *     summary: Delete an amenity (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/amenities/:id',  ...admin, ap.deleteAmenity);

// ── Coaches ───────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/coaches:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all coaches (admin — includes unapproved, pending first)
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, approved, inactive] }
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: sport_id
 *         schema: { type: integer }
 *       - in: query
 *         name: city
 *         schema: { type: string }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *     responses:
 *       200: { description: Coaches list }
 */
router.get   ('/coaches',              ...admin, ap.listCoaches);

/**
 * @swagger
 * /admin/coaches/{id}:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Get coach by ID (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Coach detail }
 *       404: { description: Not found }
 */
router.get   ('/coaches/:id',          ...admin, ap.getCoach);

/**
 * @swagger
 * /admin/coaches:
 *   post:
 *     tags: [AdminPanel]
 *     summary: Create a coach with photo upload (admin)
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [name, sport_id]
 *             properties:
 *               name:        { type: string }
 *               sport_id:    { type: integer }
 *               bio:         { type: string }
 *               experience:  { type: integer }
 *               hourly_rate: { type: number }
 *               photo:       { type: string, format: binary }
 *     responses:
 *       201: { description: Coach created }
 */
router.post  ('/coaches',              ...admin, uploadCoach, ap.createCoach);

/**
 * @swagger
 * /admin/coaches/{id}:
 *   put:
 *     tags: [AdminPanel]
 *     summary: Update a coach (admin)
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
 *               name:        { type: string }
 *               bio:         { type: string }
 *               experience:  { type: integer }
 *               hourly_rate: { type: number }
 *               photo:       { type: string, format: binary }
 *     responses:
 *       200: { description: Updated }
 */
router.put   ('/coaches/:id',          ...admin, uploadCoach, ap.updateCoach);

/**
 * @swagger
 * /admin/coaches/{id}/approve:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Approve a coach (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Approved }
 */
router.patch ('/coaches/:id/approve',  ...admin, ap.approveCoach);

/**
 * @swagger
 * /admin/coaches/{id}:
 *   delete:
 *     tags: [AdminPanel]
 *     summary: Delete a coach (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/coaches/:id',          ...admin, ap.deleteCoach);

/**
 * @swagger
 * /admin/coaches/{id}/reject:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Refuse a coach application, with a reason
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
 *               reason: { type: string }
 *     responses:
 *       200: { description: Rejected — the coach is told why }
 *       404: { description: Not found }
 */
router.patch ('/coaches/:id/reject',   ...admin, ap.rejectCoach);

/**
 * @swagger
 * /admin/coaches/{id}/password:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Issue or reset a coach's login password
 *     description: Signs the coach out everywhere by revoking their refresh tokens.
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
 *             required: [password]
 *             properties:
 *               password: { type: string, minLength: 6 }
 *     responses:
 *       200: { description: Password set }
 *       400: { description: Password too short, or the coach has no email }
 *       404: { description: Not found }
 */
router.patch ('/coaches/:id/password', ...admin, ap.setCoachPassword);

// ── Coaching sessions and ground registrations ────────────────────────────────

/**
 * @swagger
 * /admin/coach-bookings:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Every coaching session on the platform
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, confirmed, rejected, cancelled, completed] }
 *       - in: query
 *         name: coach_id
 *         schema: { type: integer }
 *       - in: query
 *         name: date
 *         schema: { type: string, format: date }
 *     responses:
 *       200: { description: Coaching sessions }
 */
router.get   ('/coach-bookings',       ...admin, ap.listCoachBookings);

/**
 * @swagger
 * /admin/coach-grounds:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Every coach registration at a ground, and where it stands
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, approved, rejected] }
 *       - in: query
 *         name: coach_id
 *         schema: { type: integer }
 *       - in: query
 *         name: ground_id
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Coach registrations with their ground and owner }
 */
router.get   ('/coach-grounds',        ...admin, ap.listCoachGrounds);

// ── Bookings ──────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/bookings:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all bookings (admin)
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, confirmed, cancelled, completed] }
 *       - in: query
 *         name: ground_id
 *         schema: { type: integer }
 *       - in: query
 *         name: user_id
 *         schema: { type: integer }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Paginated bookings list }
 */
router.get   ('/bookings',          ...admin, bookingCtrl.list);

/**
 * @swagger
 * /admin/bookings/{id}:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Get booking by ID (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Booking detail }
 *       404: { description: Not found }
 */
router.get   ('/bookings/:id',      ...admin, bookingCtrl.show);

/**
 * @swagger
 * /admin/bookings/{id}/cancel:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Cancel a booking (admin)
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
router.patch ('/bookings/:id/cancel', ...admin, ap.cancelBooking);

// ── Payments ──────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/payments:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all payments (admin)
 *     parameters:
 *       - in: query
 *         name: payment_status
 *         schema: { type: string, enum: [pending, success, failed, refunded] }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Paginated payments list }
 */
router.get   ('/payments',         ...admin, paymentCtrl.list);

/**
 * @swagger
 * /admin/payments/{id}:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Get payment by ID (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Payment detail }
 */
router.get   ('/payments/:id',     ...admin, paymentCtrl.show);

/**
 * @swagger
 * /admin/payments/{id}/status:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Update payment status (admin)
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
 *             required: [payment_status]
 *             properties:
 *               payment_status: { type: string, enum: [pending, success, failed, refunded] }
 *     responses:
 *       200: { description: Status updated }
 */
router.patch ('/payments/:id/status', ...admin, ap.updatePaymentStatus);

// ── Games ─────────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/games:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all games (admin)
 *     parameters:
 *       - in: query
 *         name: visibility
 *         schema: { type: string, enum: [public, private] }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Games list }
 */
router.get   ('/games',      ...admin, ap.listGames);

/**
 * @swagger
 * /admin/games/{id}:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Get game by ID (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Game detail }
 *       404: { description: Not found }
 */
router.get   ('/games/:id',  ...admin, ap.getGame);

/**
 * @swagger
 * /admin/games/{id}:
 *   delete:
 *     tags: [AdminPanel]
 *     summary: Delete a game (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/games/:id',  ...admin, ap.deleteGame);

// ── Reviews ───────────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/reviews:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List all reviews (admin)
 *     parameters:
 *       - in: query
 *         name: review_type
 *         schema: { type: string, enum: [ground, sport, coach, application] }
 *       - in: query
 *         name: ground_id
 *         schema: { type: integer }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *     responses:
 *       200: { description: Reviews list }
 */
router.get   ('/reviews',      ...admin, ap.listReviews);

/**
 * @swagger
 * /admin/reviews/{id}:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Get review by ID (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Review detail }
 */
router.get   ('/reviews/:id',  ...admin, ap.getReview);

/**
 * @swagger
 * /admin/reviews/{id}:
 *   delete:
 *     tags: [AdminPanel]
 *     summary: Delete a review (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Deleted }
 */
router.delete('/reviews/:id',  ...admin, ap.deleteReview);

// ── Vendor Settlements ─────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/vendors:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List vendors with settlement stats (admin)
 *     parameters:
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200: { description: Vendors list with earnings }
 */
router.get   ('/vendors',                ...admin, ap.listVendors);

/**
 * @swagger
 * /admin/vendors/{id}/bookings:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Get vendor's bookings (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Vendor bookings }
 *       404: { description: Vendor not found }
 */
router.get   ('/vendors/:id/bookings',   ...admin, ap.getVendorBookings);

/**
 * @swagger
 * /admin/vendors/{id}/stats:
 *   get:
 *     tags: [AdminPanel]
 *     summary: Get vendor statistics (admin)
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Vendor stats }
 *       404: { description: Vendor not found }
 */
router.get   ('/vendors/:id/stats',      ...admin, ap.getVendorStats);

/**
 * @swagger
 * /admin/ground-owners/{id}:
 *   put:
 *     tags: [AdminPanel]
 *     summary: Update a ground owner's profile and moderation flags
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
 *             properties:
 *               name:        { type: string }
 *               email:       { type: string }
 *               mobile:      { type: string }
 *               is_active:   { type: boolean }
 *               is_approved: { type: boolean }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 *       422: { description: Validation failed }
 */
router.put   ('/ground-owners/:id',          ...admin, ap.updateGroundOwner);

/**
 * @swagger
 * /admin/ground-owners/{id}/password:
 *   patch:
 *     tags: [AdminPanel]
 *     summary: Reset a ground owner's password and sign them out everywhere
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
 *             properties:
 *               password: { type: string, minLength: 8 }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 *       422: { description: Validation failed }
 */
router.patch ('/ground-owners/:id/password', ...admin, ap.resetGroundOwnerPassword);

/**
 * @swagger
 * /admin/users/{id}:
 *   put:
 *     tags: [AdminPanel]
 *     summary: Update a customer's profile
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
 *             properties:
 *               name:      { type: string }
 *               email:     { type: string }
 *               mobile:    { type: string }
 *               is_active: { type: boolean }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 *       422: { description: Validation failed }
 */
router.put   ('/users/:id',                  ...admin, ap.updateUser);

/**
 * @swagger
 * /admin/grounds/{id}:
 *   put:
 *     tags: [AdminPanel]
 *     summary: Update any ground, including its owner and approval state
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
 *             properties:
 *               name:        { type: string }
 *               address:     { type: string }
 *               is_active:   { type: boolean }
 *               is_approved: { type: boolean }
 *               owner_id:    { type: integer }
 *     responses:
 *       200: { description: Updated }
 *       404: { description: Not found }
 *       422: { description: Validation failed }
 */
router.put   ('/grounds/:id',                ...admin, ap.updateGround);

// ── App versions ──────────────────────────────────────────────────────────────
/**
 * @swagger
 * /admin/app-versions:
 *   get:
 *     tags: [AdminPanel]
 *     summary: List the version thresholds for every platform
 *     description: >
 *       Always returns a row for both android and ios, filled with nulls and
 *       is_active false for a platform never configured, so the panel can offer
 *       it for editing.
 *     responses:
 *       200: { description: App versions retrieved }
 *       403: { description: Admin role required }
 */
router.get   ('/app-versions',               ...admin, appVersionCtrl.list);

/**
 * @swagger
 * /admin/app-versions/{platform}:
 *   put:
 *     tags: [AdminPanel]
 *     summary: Set the update thresholds for one platform
 *     description: >
 *       Admin only — these values decide whether every installed app prompts or
 *       is blocked, so nothing below the admin role may write them. Raising
 *       min_supported_version retires every older build on the next launch.
 *     parameters:
 *       - in: path
 *         name: platform
 *         required: true
 *         schema: { type: string, enum: [android, ios] }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [latest_version, min_supported_version]
 *             properties:
 *               latest_version:        { type: string,  example: '1.4.0' }
 *               min_supported_version: { type: string,  example: '1.2.0' }
 *               update_url:            { type: string,  nullable: true }
 *               release_notes:         { type: string,  nullable: true }
 *               is_active:             { type: boolean, example: true }
 *     responses:
 *       200: { description: App version updated }
 *       400: { description: Minimum newer than latest }
 *       403: { description: Admin role required }
 *       422: { description: Validation failed }
 */
router.put   ('/app-versions/:platform',     ...admin, upsertVersion, validate, appVersionCtrl.upsert);

// ── Admin accounts ────────────────────────────────────────────────────────────
// Own router: every route past /me needs the super-admin tier on top of the
// admin role, and the self-action guards read better in one file.
router.use('/admins', require('./admin.routes'));

// ── Database schema ───────────────────────────────────────────────────────────
// Own router: it owns four routes plus their own admin guard, and the DDL it
// runs deserves to be read in one file rather than mixed in among CRUD.
router.use('/schema', require('./schema.routes'));

module.exports = router;
