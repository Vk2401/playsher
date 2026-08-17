/**
 * OTP Controller — mobile-number based auth for the Flutter app
 * For production: replace console.log with actual SMS gateway (Twilio, etc.)
 */
const bcrypt = require('bcryptjs');
const { User, RefreshToken } = require('../models');
const { generateAccessToken, generateRefreshToken } = require('../utils/jwt.utils');
const { success, error } = require('../utils/response');
const { REFRESH_EXPIRES_DAYS } = require('../config/jwt');
const { sendSms } = require('../utils/sms.utils');

const SALT_ROUNDS = 12;

// In-memory OTP store: mobile -> { otp, expiresAt, verified }
const otpStore = new Map();

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

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

/**
 * POST /auth/send-otp
 * Body: { mobile }
 * Sends a 6-digit OTP to the mobile number (logs to console in dev).
 */
exports.sendOtp = async (req, res) => {
  try {
    const { mobile } = req.body;
    if (!mobile) return error(res, 'mobile is required.', 422);

    // Create a placeholder user record if this mobile hasn't been seen before.
    // name is required (NOT NULL) so we use a temporary placeholder.
    await User.findOrCreate({
      where: { mobile },
      defaults: {
        name: 'User',
        mobile,
        password_hash: await bcrypt.hash(mobile + Date.now(), SALT_ROUNDS),
        is_active: true,
        is_verified: false,
      },
    });

    const otp = generateOtp();
    otpStore.set(mobile, { otp, expiresAt: Date.now() + 5 * 60 * 1000 });

    console.log(`[OTP] mobile=${mobile}  otp=${otp}`);
    await sendSms(mobile, `Your Playsher OTP is ${otp}. Valid for 5 minutes.`);

    return success(res, 'OTP sent successfully.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * POST /auth/verify-otp
 * Body: { mobile, otp }
 * - If user exists  → returns tokens (login)
 * - If new user     → returns { new_user: true, mobile } (must complete registration)
 */
exports.verifyOtp = async (req, res) => {
  try {
    const { mobile, otp } = req.body;
    if (!mobile || !otp) return error(res, 'mobile and otp are required.', 422);

    const stored = otpStore.get(mobile);
    if (!stored || stored.otp !== String(otp) || Date.now() > stored.expiresAt) {
      return error(res, 'Invalid or expired OTP.', 401);
    }

    // Mark verified so complete-registration can proceed without re-sending OTP
    otpStore.set(mobile, { ...stored, verified: true });

    // User always exists (created in sendOtp). Check if profile is complete.
    const user = await User.findOne({ where: { mobile, deleted_at: null } });
    if (!user) return error(res, 'User not found. Please request OTP again.', 404);

    if (!user.is_active) return error(res, 'Account is deactivated.', 403);

    // If name is still the placeholder "User" and not verified, treat as new user
    if (!user.is_verified) {
      return success(res, 'OTP verified. Please complete your profile.', {
        new_user: true,
        mobile,
      });
    }

    // Existing user — issue tokens
    otpStore.delete(mobile);
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

/**
 * PATCH /auth/update-location
 * Body: { latitude, longitude }
 * Saves the user's current coordinates.
 */
exports.updateLocation = async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    if (latitude == null || longitude == null) {
      return error(res, 'latitude and longitude are required.', 422);
    }

    await User.update(
      { current_latitude: latitude, current_longitude: longitude },
      { where: { id: req.user.id } }
    );

    return success(res, 'Location updated.');
  } catch (err) {
    return error(res, err.message, 500);
  }
};

/**
 * POST /auth/complete-registration
 * Body: { name, email (optional), mobile }
 * Mobile must have been verified via verify-otp first.
 */
exports.completeRegistration = async (req, res) => {
  try {
    const { name, email, mobile } = req.body;
    if (!name || !mobile) return error(res, 'name and mobile are required.', 422);

    const stored = otpStore.get(mobile);
    if (!stored?.verified) {
      return error(res, 'OTP not verified for this mobile. Please verify OTP first.', 403);
    }

    // Find the placeholder user created during sendOtp
    let user = await User.findOne({ where: { mobile, deleted_at: null } });
    if (!user) return error(res, 'User not found. Please request OTP again.', 404);

    otpStore.delete(mobile);

    // Update placeholder with real profile details
    await user.update({
      name,
      email: email || null,
      is_verified: true,
      is_active: true,
    });

    const payload = { id: user.id, role: 'user' };
    const accessToken = generateAccessToken(payload);
    const refreshTokenStr = generateRefreshToken(payload);
    await storeRefreshToken(user.id, 'user', refreshTokenStr);

    return success(
      res,
      'Registration successful.',
      {
        access_token: accessToken,
        refresh_token: refreshTokenStr,
        user: { id: user.id, name: user.name, mobile: user.mobile, email: user.email },
      },
      201,
    );
  } catch (err) {
    return error(res, err.message, 500);
  }
};
