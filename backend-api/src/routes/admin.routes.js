/**
 * Admin account routes — mounted at /api/v1/admin/admins
 *
 * Two tiers of guard. Every route needs the `admin` role; every route except
 * /me additionally needs the super-admin tier, checked against the row rather
 * than the token so a demotion takes effect immediately.
 */

/**
 * @swagger
 * tags:
 *   name: Admins
 *   description: Admin account management (requires the super-admin tier)
 */

const router = require('express').Router();

const { verifyToken, requireRole } = require('../middleware/auth');
const { requireSuperAdmin } = require('../middleware/superAdmin');
const validate = require('../middleware/validate');
const ctrl = require('../controllers/admin.controller');
const {
  createAdmin, updateAdmin, adminIdOnly, resetPassword,
} = require('../validators/admin.validator');

const admin = [verifyToken, requireRole('admin')];
const superAdmin = [...admin, requireSuperAdmin];

/**
 * @swagger
 * /admin/admins/me:
 *   get:
 *     tags: [Admins]
 *     summary: The signed-in admin, with their tier
 *     description: >
 *       Open to any admin. `is_super_admin` tells the panel whether to offer the
 *       Admins screen, so it never shows a link that answers 403.
 *       `is_bootstrap_super_admin` is true when the tier is inherited because no
 *       super admin exists yet, rather than stored on the row.
 *     security: [{ bearerAuth: [] }]
 *     responses:
 *       200: { description: The current admin }
 *       403: { description: Admin role required }
 */
router.get('/me', admin, ctrl.me);

/**
 * @swagger
 * /admin/admins:
 *   get:
 *     tags: [Admins]
 *     summary: List admin accounts
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *         description: Matches name, email or mobile
 *       - in: query
 *         name: role
 *         schema: { type: string, enum: [super_admin, admin] }
 *       - in: query
 *         name: is_active
 *         schema: { type: boolean }
 *     responses:
 *       200: { description: Admins, paginated. Password hashes are never returned. }
 *       403: { description: Super-admin tier required }
 */
router.get('/', superAdmin, ctrl.list);

/**
 * @swagger
 * /admin/admins/{id}:
 *   get:
 *     tags: [Admins]
 *     summary: Get one admin
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: The admin }
 *       403: { description: Super-admin tier required }
 *       404: { description: Admin not found }
 */
router.get('/:id', superAdmin, adminIdOnly, validate, ctrl.show);

/**
 * @swagger
 * /admin/admins:
 *   post:
 *     tags: [Admins]
 *     summary: Create an admin account
 *     description: >
 *       Replaces onboarding a colleague through /auth/admin/register with the
 *       shared ADMIN_SECRET.
 *     security: [{ bearerAuth: [] }]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, email, mobile, password]
 *             properties:
 *               name:     { type: string,  example: 'Priya R' }
 *               email:    { type: string,  example: 'priya@playsher.com' }
 *               mobile:   { type: string,  example: '9876543210' }
 *               password: { type: string,  minLength: 8 }
 *               role:     { type: string,  enum: [super_admin, admin], default: admin }
 *     responses:
 *       201: { description: Admin created }
 *       403: { description: Super-admin tier required }
 *       409: { description: Email or mobile already in use }
 *       422: { description: Validation failed }
 */
router.post('/', superAdmin, createAdmin, validate, ctrl.create);

/**
 * @swagger
 * /admin/admins/{id}:
 *   put:
 *     tags: [Admins]
 *     summary: Update an admin's details or tier
 *     description: >
 *       You cannot change your own role, and the last active super admin cannot
 *       be demoted — either would leave nobody able to promote anyone.
 *     security: [{ bearerAuth: [] }]
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
 *               email:  { type: string }
 *               mobile: { type: string }
 *               role:   { type: string, enum: [super_admin, admin] }
 *     responses:
 *       200: { description: Admin updated }
 *       403: { description: Super-admin tier required, or changing your own role }
 *       409: { description: Email/mobile clash, or last super admin }
 *       422: { description: Validation failed }
 */
router.put('/:id', superAdmin, updateAdmin, validate, ctrl.update);

/**
 * @swagger
 * /admin/admins/{id}/toggle-status:
 *   patch:
 *     tags: [Admins]
 *     summary: Activate or deactivate an admin
 *     description: >
 *       Accounts are deactivated, never deleted. Refused on your own account, on
 *       the last active admin, and on the last active super admin.
 *     security: [{ bearerAuth: [] }]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200: { description: Status changed }
 *       403: { description: Super-admin tier required, or acting on yourself }
 *       409: { description: Would leave no active admin or no super admin }
 */
router.patch('/:id/toggle-status', superAdmin, adminIdOnly, validate, ctrl.toggleStatus);

/**
 * @swagger
 * /admin/admins/{id}/password:
 *   patch:
 *     tags: [Admins]
 *     summary: Reset another admin's password
 *     description: >
 *       An administrative reset, so the current password is not required. Your
 *       own password is changed through /auth/change-password, which does
 *       require it.
 *     security: [{ bearerAuth: [] }]
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
 *             required: [new_password]
 *             properties:
 *               new_password: { type: string, minLength: 8 }
 *     responses:
 *       200: { description: Password reset }
 *       403: { description: Super-admin tier required, or your own account }
 *       422: { description: Validation failed }
 */
router.patch('/:id/password', superAdmin, resetPassword, validate, ctrl.resetPassword);

module.exports = router;
