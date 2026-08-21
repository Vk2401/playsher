const bcrypt = require('bcryptjs');
const { Op } = require('sequelize');

const { Admin } = require('../models');
const { success, error } = require('../utils/response');
const { getPagination, paginationMeta } = require('../utils/helpers');
const { resolveSuperAdmin } = require('../middleware/superAdmin');

const SALT_ROUNDS = 10;

/** Never let a hash out of the API, not even to a super admin. */
const SAFE_FIELDS = ['id', 'name', 'email', 'mobile', 'role', 'profile_picture',
  'is_active', 'created_at', 'updated_at'];

/**
 * An admin may not act on their own row here.
 *
 * Deactivating or demoting yourself is the one mistake with no way back — a sole
 * super admin who demotes themselves leaves the panel with nobody able to
 * promote anyone. Own name, email and password are changed through
 * /profile and /auth/change-password, which is why this is a refusal rather
 * than a special case.
 */
function isSelf(req, targetId) {
  return Number(req.user.id) === Number(targetId);
}

// GET /admin/admins
exports.list = async (req, res) => {
  try {
    const { page, limit, offset } = getPagination(req.query);
    const where = {};

    if (req.query.role) where.role = req.query.role;
    if (req.query.is_active !== undefined) where.is_active = req.query.is_active === 'true';
    if (req.query.search) {
      const like = { [Op.like]: `%${req.query.search}%` };
      where[Op.or] = [{ name: like }, { email: like }, { mobile: like }];
    }

    const { count, rows } = await Admin.findAndCountAll({
      where,
      attributes: SAFE_FIELDS,
      order: [['id', 'ASC']],
      limit,
      offset,
    });
    return success(res, 'Admins retrieved.', rows, 200, paginationMeta(count, page, limit));
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// GET /admin/admins/me
// Lets the panel decide whether to offer the Admins screen at all, rather than
// showing a link that answers 403. Available to any admin, not just a super one.
exports.me = async (req, res) => {
  try {
    const admin = await Admin.findByPk(req.user.id, { attributes: SAFE_FIELDS });
    if (!admin) return error(res, 'Account not found.', 404);

    const result = await resolveSuperAdmin(req.user.id);
    return success(res, 'Current admin retrieved.', {
      ...admin.get({ plain: true }),
      is_super_admin: result.ok,
      // True while the tier is inherited from the bootstrap rule rather than
      // stored, so the panel can say so instead of implying it was granted.
      is_bootstrap_super_admin: Boolean(result.bootstrapped),
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// GET /admin/admins/:id
exports.show = async (req, res) => {
  try {
    const admin = await Admin.findByPk(req.params.id, { attributes: SAFE_FIELDS });
    if (!admin) return error(res, 'Admin not found.', 404);
    return success(res, 'Admin retrieved.', admin);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// POST /admin/admins
exports.create = async (req, res) => {
  try {
    const { name, email, mobile, password, role } = req.body;

    const clash = await Admin.findOne({ where: { [Op.or]: [{ email }, { mobile }] } });
    if (clash) {
      const field = clash.email === email ? 'email' : 'mobile';
      return error(res, `An admin with that ${field} already exists.`, 409);
    }

    const admin = await Admin.create({
      name,
      email,
      mobile,
      role: role === 'super_admin' ? 'super_admin' : 'admin',
      password_hash: await bcrypt.hash(password, SALT_ROUNDS),
    });

    const created = await Admin.findByPk(admin.id, { attributes: SAFE_FIELDS });
    return success(res, 'Admin created.', created, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// PUT /admin/admins/:id
exports.update = async (req, res) => {
  try {
    const admin = await Admin.findByPk(req.params.id);
    if (!admin) return error(res, 'Admin not found.', 404);

    const { name, email, mobile, role } = req.body;

    if (role && role !== admin.role && isSelf(req, admin.id)) {
      return error(res, 'You cannot change your own role.', 403);
    }

    if (email || mobile) {
      const clash = await Admin.findOne({
        where: {
          id: { [Op.ne]: admin.id },
          [Op.or]: [
            ...(email ? [{ email }] : []),
            ...(mobile ? [{ mobile }] : []),
          ],
        },
      });
      if (clash) return error(res, 'Another admin already uses that email or mobile.', 409);
    }

    // Demoting the last super admin leaves nobody able to promote anyone, so it
    // is refused for the same reason as acting on yourself.
    if (role === 'admin' && admin.role === 'super_admin') {
      const others = await Admin.count({
        where: { role: 'super_admin', is_active: true, id: { [Op.ne]: admin.id } },
      });
      if (others === 0) {
        return error(res, 'This is the only super admin — promote another one first.', 409);
      }
    }

    const patch = {};
    if (name !== undefined) patch.name = name;
    if (email !== undefined) patch.email = email;
    if (mobile !== undefined) patch.mobile = mobile;
    if (role !== undefined) patch.role = role;

    await admin.update(patch);

    const updated = await Admin.findByPk(admin.id, { attributes: SAFE_FIELDS });
    return success(res, 'Admin updated.', updated);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// PATCH /admin/admins/:id/toggle-status
exports.toggleStatus = async (req, res) => {
  try {
    const admin = await Admin.findByPk(req.params.id);
    if (!admin) return error(res, 'Admin not found.', 404);

    if (isSelf(req, admin.id)) {
      return error(res, 'You cannot deactivate your own account.', 403);
    }

    const nextActive = !admin.is_active;

    if (!nextActive) {
      const othersActive = await Admin.count({
        where: { is_active: true, id: { [Op.ne]: admin.id } },
      });
      if (othersActive === 0) {
        return error(res, 'This is the only active admin — the panel would be locked out.', 409);
      }
      if (admin.role === 'super_admin') {
        const otherSupers = await Admin.count({
          where: { role: 'super_admin', is_active: true, id: { [Op.ne]: admin.id } },
        });
        if (otherSupers === 0) {
          return error(res, 'This is the only active super admin — promote another one first.', 409);
        }
      }
    }

    await admin.update({ is_active: nextActive });

    const updated = await Admin.findByPk(admin.id, { attributes: SAFE_FIELDS });
    return success(res, nextActive ? 'Admin activated.' : 'Admin deactivated.', updated);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// PATCH /admin/admins/:id/password
// Resets another admin's password. Deliberately does not accept the current one:
// this is an administrative reset, not a self-service change. An admin changing
// their own password goes through /auth/change-password, which does require it.
exports.resetPassword = async (req, res) => {
  try {
    const admin = await Admin.findByPk(req.params.id);
    if (!admin) return error(res, 'Admin not found.', 404);

    if (isSelf(req, admin.id)) {
      return error(res, 'Use change password on your own profile instead.', 403);
    }

    await admin.update({
      password_hash: await bcrypt.hash(req.body.new_password, SALT_ROUNDS),
    });
    return success(res, 'Password reset.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
