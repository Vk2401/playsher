const { Admin } = require('../models');
const { error } = require('../utils/response');

/**
 * Is this admin a super admin?
 *
 * Read from the row on every call rather than from the token. A tier carried in
 * a JWT stays valid until the token expires, so demoting someone would leave
 * them managing admin accounts for another fifteen minutes — the one window
 * that matters most.
 *
 * Bootstrap: if no super admin exists anywhere, the oldest active admin is
 * treated as one. Adding the column defaults every existing row to `admin`,
 * which would otherwise leave nobody able to promote anybody — the panel would
 * ship locked. The fallback applies only while the count is genuinely zero, so
 * it cannot be used to escalate once a super admin exists.
 *
 * @returns {Promise<{ok: boolean, admin?: object, reason?: string}>}
 */
async function resolveSuperAdmin(adminId) {
  const admin = await Admin.findByPk(adminId);
  if (!admin) return { ok: false, reason: 'Account no longer exists.' };
  if (!admin.is_active) return { ok: false, reason: 'This account is deactivated.' };

  if (admin.role === 'super_admin') return { ok: true, admin };

  const superAdmins = await Admin.count({ where: { role: 'super_admin', is_active: true } });
  if (superAdmins === 0) {
    const oldest = await Admin.findOne({
      where: { is_active: true },
      order: [['id', 'ASC']],
    });
    if (oldest && oldest.id === admin.id) return { ok: true, admin, bootstrapped: true };
  }

  return { ok: false, reason: 'Only a super admin can manage admin accounts.' };
}

/**
 * Middleware: gate an endpoint on the super admin tier.
 * Runs after verifyToken + requireRole('admin'), and sets req.admin to the row.
 */
async function requireSuperAdmin(req, res, next) {
  try {
    const result = await resolveSuperAdmin(req.user.id);
    if (!result.ok) return error(res, result.reason, 403);
    req.admin = result.admin;
    return next();
  } catch (err) {
    return error(res, err.message, 500);
  }
}

module.exports = { requireSuperAdmin, resolveSuperAdmin };
