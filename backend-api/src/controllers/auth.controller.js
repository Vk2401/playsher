const bcrypt = require('bcryptjs');
const { Op } = require('sequelize');
const { Admin, User, GroundOwner, RefreshToken } = require('../models');
const { generateAccessToken, generateRefreshToken, verifyToken } = require('../utils/jwt.utils');
const { success, error } = require('../utils/response');
const { REFRESH_EXPIRES_DAYS } = require('../config/jwt');

const SALT_ROUNDS = 12;

function refreshExpiry() {
  const d = new Date();
  d.setDate(d.getDate() + REFRESH_EXPIRES_DAYS);
  return d;
}

async function storeRefreshToken(userId, userType, token) {
  await RefreshToken.create({
    user_id: userId,
    user_type: userType,
    token,
    expires_at: refreshExpiry(),
    is_revoked: false,
  });
}

// ── Admin ────────────────────────────────────────────────────────────────────

exports.adminRegister = async (req, res) => {
  try {
    const { name, email, mobile, password, admin_secret } = req.body;
    if (admin_secret !== process.env.ADMIN_SECRET) {
      return error(res, 'Invalid admin secret.', 403);
    }
    const exists = await Admin.findOne({ where: { [Op.or]: [{ email }, { mobile }] } });
    if (exists) return error(res, 'Email or mobile already registered.');
    const password_hash = await bcrypt.hash(password, SALT_ROUNDS);
    const admin = await Admin.create({ name, email, mobile, password_hash });
    const payload = { id: admin.id, role: 'admin' };
    const accessToken = generateAccessToken(payload);
    const refreshTokenStr = generateRefreshToken(payload);
    await storeRefreshToken(admin.id, 'admin', refreshTokenStr);
    return success(res, 'Admin registered.', { access_token: accessToken, refresh_token: refreshTokenStr }, 201);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body;
    const admin = await Admin.findOne({ where: { email } });
    if (!admin || !(await bcrypt.compare(password, admin.password_hash))) {
      return error(res, 'Invalid credentials.', 401);
    }
    if (!admin.is_active) return error(res, 'Account is deactivated.', 403);
    const payload = { id: admin.id, role: 'admin' };
    const accessToken = generateAccessToken(payload);
    const refreshTokenStr = generateRefreshToken(payload);
    await storeRefreshToken(admin.id, 'admin', refreshTokenStr);
    return success(res, 'Login successful.', {
      access_token: accessToken,
      refresh_token: refreshTokenStr,
      user: { id: admin.id, name: admin.name, email: admin.email, mobile: admin.mobile, role: 'admin' },
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// ── User ─────────────────────────────────────────────────────────────────────

exports.userRegister = async (req, res) => {
  try {
    const { name, mobile, email, password } = req.body;
    const exists = await User.findOne({
      where: { [Op.or]: [{ mobile }, ...(email ? [{ email }] : [])] },
    });
    if (exists) return error(res, 'Mobile or email already registered.');
    const password_hash = await bcrypt.hash(password, SALT_ROUNDS);
    const user = await User.create({ name, mobile, email, password_hash });
    const payload = { id: user.id, role: 'user' };
    const accessToken = generateAccessToken(payload);
    const refreshTokenStr = generateRefreshToken(payload);
    await storeRefreshToken(user.id, 'user', refreshTokenStr);
    return success(
      res,
      'Registration successful.',
      { access_token: accessToken, refresh_token: refreshTokenStr, user: { id: user.id, name: user.name, mobile: user.mobile } },
      201
    );
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.userLogin = async (req, res) => {
  try {
    const { mobile, password } = req.body;
    const user = await User.findOne({ where: { mobile, deleted_at: null } });
    if (!user || !(await bcrypt.compare(password, user.password_hash || ''))) {
      return error(res, 'Invalid credentials.', 401);
    }
    if (!user.is_active) return error(res, 'Account is deactivated.', 403);
    const payload = { id: user.id, role: 'user' };
    const accessToken = generateAccessToken(payload);
    const refreshTokenStr = generateRefreshToken(payload);
    await storeRefreshToken(user.id, 'user', refreshTokenStr);
    return success(res, 'Login successful.', {
      access_token: accessToken,
      refresh_token: refreshTokenStr,
      user: { id: user.id, name: user.name, mobile: user.mobile, email: user.email },
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// ── Ground Owner ──────────────────────────────────────────────────────────────

exports.groundOwnerRegister = async (req, res) => {
  try {
    const { name, email, mobile, password } = req.body;
    const exists = await GroundOwner.findOne({ where: { [Op.or]: [{ email }, { mobile }] } });
    if (exists) return error(res, 'Email or mobile already registered.');
    const password_hash = await bcrypt.hash(password, SALT_ROUNDS);
    const owner = await GroundOwner.create({ name, email, mobile, password_hash });
    return success(
      res,
      'Registration submitted. Await admin approval.',
      { id: owner.id, name: owner.name, is_approved: owner.is_approved },
      201
    );
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.groundOwnerLogin = async (req, res) => {
  try {
    const { email, password } = req.body;
    const owner = await GroundOwner.findOne({ where: { email } });
    if (!owner || !(await bcrypt.compare(password, owner.password_hash))) {
      return error(res, 'Invalid credentials.', 401);
    }
    if (!owner.is_active) return error(res, 'Account is deactivated.', 403);
    if (!owner.is_approved) return error(res, 'Account pending admin approval.', 403);
    const payload = { id: owner.id, role: 'ground_owner' };
    const accessToken = generateAccessToken(payload);
    const refreshTokenStr = generateRefreshToken(payload);
    await storeRefreshToken(owner.id, 'ground_owner', refreshTokenStr);
    return success(res, 'Login successful.', {
      access_token: accessToken,
      refresh_token: refreshTokenStr,
      user: { id: owner.id, name: owner.name, email: owner.email, mobile: owner.mobile, role: 'ground_owner' },
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// ── Token rotation ────────────────────────────────────────────────────────────

exports.refreshToken = async (req, res) => {
  try {
    const { refresh_token } = req.body;
    const stored = await RefreshToken.findOne({ where: { token: refresh_token } });
    if (!stored || stored.is_revoked || new Date(stored.expires_at) < new Date()) {
      return error(res, 'Invalid or expired refresh token.', 401);
    }
    let decoded;
    try {
      decoded = verifyToken(refresh_token);
    } catch {
      return error(res, 'Invalid refresh token.', 401);
    }
    // Revoke old token
    await stored.update({ is_revoked: true });
    const payload = { id: decoded.id, role: decoded.role };
    const newAccessToken = generateAccessToken(payload);
    const newRefreshToken = generateRefreshToken(payload);
    await storeRefreshToken(decoded.id, decoded.role, newRefreshToken);
    return success(res, 'Token refreshed.', { access_token: newAccessToken, refresh_token: newRefreshToken });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

exports.logout = async (req, res) => {
  try {
    const { refresh_token } = req.body;
    if (refresh_token) {
      await RefreshToken.update({ is_revoked: true }, { where: { token: refresh_token } });
    }
    return success(res, 'Logged out successfully.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};
