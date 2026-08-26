/**
 * Coach Panel Routes — mounted at /api/v1/coach
 * All routes require the coach role and act on the token holder's own account.
 */

/**
 * @swagger
 * tags:
 *   name: CoachPanel
 *   description: Coach panel — own profile, pricing, availability, ground registrations and sessions (requires coach role)
 */

const router = require('express').Router();
const { verifyToken, requireRole } = require('../middleware/auth');
const { uploadCoach } = require('../middleware/upload');
const cp = require('../controllers/coachPanel.controller');

const coach = [verifyToken, requireRole('coach')];

// ── Profile ───────────────────────────────────────────────────────────────────

/**
 * @swagger
 * /coach/profile:
 *   get:
 *     tags: [CoachPanel]
 *     summary: My coach profile
 *     responses:
 *       200: { description: Coach profile }
 *       404: { description: Not found }
 */
router.get   ('/profile',                ...coach, cp.getProfile);

/**
 * @swagger
 * /coach/profile:
 *   put:
 *     tags: [CoachPanel]
 *     summary: Update my profile and my per-slot price
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               name:               { type: string }
 *               mobile:             { type: string }
 *               city:               { type: string }
 *               sport_id:           { type: integer }
 *               sport_name:         { type: string }
 *               experience_years:   { type: integer }
 *               level:              { type: string, enum: [beginner, intermediate, advanced, professional] }
 *               about:              { type: string }
 *               experience_details: { type: string }
 *               awards:             { type: string }
 *               qualities:          { type: string }
 *               price_per_slot:     { type: number, description: Rupees for one 30-minute block }
 *               profile_image:      { type: string, format: binary }
 *     responses:
 *       200: { description: Profile updated }
 *       400: { description: Nothing updatable supplied, or an invalid price }
 */
router.put   ('/profile',                ...coach, uploadCoach, cp.updateProfile);

/**
 * @swagger
 * /coach/dashboard:
 *   get:
 *     tags: [CoachPanel]
 *     summary: Session counts, earnings and account state for the panel home
 *     responses:
 *       200: { description: Dashboard figures }
 */
router.get   ('/dashboard',              ...coach, cp.dashboard);

// ── Availability ──────────────────────────────────────────────────────────────

/**
 * @swagger
 * /coach/availability:
 *   get:
 *     tags: [CoachPanel]
 *     summary: My weekly working hours
 *     responses:
 *       200: { description: One row per configured weekday }
 */
router.get   ('/availability',           ...coach, cp.getAvailability);

/**
 * @swagger
 * /coach/availability:
 *   put:
 *     tags: [CoachPanel]
 *     summary: Replace my weekly working hours
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [days]
 *             properties:
 *               days:
 *                 type: array
 *                 items:
 *                   type: object
 *                   required: [day_of_week]
 *                   properties:
 *                     day_of_week: { type: integer, minimum: 0, maximum: 6, description: 0 = Sunday }
 *                     start_time:  { type: string, example: "07:00" }
 *                     end_time:    { type: string, example: "21:00" }
 *                     is_closed:   { type: boolean }
 *     responses:
 *       200: { description: Availability saved }
 *       400: { description: Invalid day or times }
 */
router.put   ('/availability',           ...coach, cp.setAvailability);

/**
 * @swagger
 * /coach/slots:
 *   get:
 *     tags: [CoachPanel]
 *     summary: My generated 30-minute blocks for one date
 *     parameters:
 *       - in: query
 *         name: date
 *         schema: { type: string, format: date }
 *         description: Defaults to today
 *     responses:
 *       200: { description: Slots, each flagged is_booked / is_blocked }
 *       400: { description: Bad date }
 */
router.get   ('/slots',                  ...coach, cp.listSlots);

/**
 * @swagger
 * /coach/slots/{id}/block:
 *   patch:
 *     tags: [CoachPanel]
 *     summary: Take one block off the market
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Blocked }
 *       409: { description: Already booked }
 */
router.patch ('/slots/:id/block',        ...coach, cp.blockSlot);

/**
 * @swagger
 * /coach/slots/{id}/unblock:
 *   patch:
 *     tags: [CoachPanel]
 *     summary: Reopen a block I had taken off the market
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Reopened }
 *       409: { description: Held by a session }
 */
router.patch ('/slots/:id/unblock',      ...coach, cp.unblockSlot);

// ── Ground registrations ──────────────────────────────────────────────────────

/**
 * @swagger
 * /coach/grounds:
 *   get:
 *     tags: [CoachPanel]
 *     summary: My ground registrations and their approval state
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, approved, rejected] }
 *     responses:
 *       200: { description: Registration list }
 */
router.get   ('/grounds',                ...coach, cp.listGroundLinks);

/**
 * @swagger
 * /coach/grounds/available:
 *   get:
 *     tags: [CoachPanel]
 *     summary: Grounds I have not yet asked to join
 *     parameters:
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: city
 *         schema: { type: string }
 *     responses:
 *       200: { description: Ground list }
 */
router.get   ('/grounds/available',      ...coach, cp.listAvailableGrounds);

/**
 * @swagger
 * /coach/grounds:
 *   post:
 *     tags: [CoachPanel]
 *     summary: Ask a ground's owner to let me coach there
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [ground_id]
 *             properties:
 *               ground_id:    { type: integer }
 *               request_note: { type: string }
 *     responses:
 *       201: { description: Request sent to the owner }
 *       403: { description: Coach account not approved yet }
 *       404: { description: Ground not found }
 *       409: { description: Already requested or already registered }
 */
router.post  ('/grounds',                ...coach, cp.requestGround);

/**
 * @swagger
 * /coach/grounds/{id}:
 *   delete:
 *     tags: [CoachPanel]
 *     summary: Withdraw a request or leave a ground
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Withdrawn }
 *       409: { description: Upcoming sessions still booked there }
 */
router.delete('/grounds/:id',            ...coach, cp.withdrawGround);

// ── Sessions ──────────────────────────────────────────────────────────────────

/**
 * @swagger
 * /coach/bookings:
 *   get:
 *     tags: [CoachPanel]
 *     summary: Sessions booked with me
 *     parameters:
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [pending, confirmed, rejected, cancelled, completed] }
 *       - in: query
 *         name: upcoming
 *         schema: { type: string, enum: ['true'] }
 *       - in: query
 *         name: from
 *         schema: { type: string, format: date }
 *       - in: query
 *         name: to
 *         schema: { type: string, format: date }
 *     responses:
 *       200: { description: Session list }
 */
router.get   ('/bookings',               ...coach, cp.listBookings);

/**
 * @swagger
 * /coach/bookings/{id}:
 *   get:
 *     tags: [CoachPanel]
 *     summary: One session booked with me
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Session detail }
 *       404: { description: Not found }
 */
router.get   ('/bookings/:id',           ...coach, cp.getBooking);

/**
 * @swagger
 * /coach/bookings/{id}/confirm:
 *   patch:
 *     tags: [CoachPanel]
 *     summary: Accept a session request
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
 *               coach_note: { type: string }
 *     responses:
 *       200: { description: Confirmed }
 *       409: { description: Not pending any more }
 */
router.patch ('/bookings/:id/confirm',   ...coach, cp.confirmBooking);

/**
 * @swagger
 * /coach/bookings/{id}/reject:
 *   patch:
 *     tags: [CoachPanel]
 *     summary: Decline a session and give its time back
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
 *       200: { description: Declined }
 *       409: { description: Already resolved }
 */
router.patch ('/bookings/:id/reject',    ...coach, cp.rejectBooking);

/**
 * @swagger
 * /coach/bookings/{id}/complete:
 *   patch:
 *     tags: [CoachPanel]
 *     summary: Mark a confirmed session as done
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Completed }
 *       409: { description: Not a confirmed session }
 */
router.patch ('/bookings/:id/complete',  ...coach, cp.completeBooking);

module.exports = router;
