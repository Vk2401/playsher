/**
 * OTP Controller — mobile-number based auth for the Flutter app
 * OTPs are stored in the `otps` table so they survive restarts and work across
 * multiple processes. For production: configure the SMS gateway in sms.utils
 * and make sure OTP_DEV_BYPASS is unset.
 */
const bcrypt = require('bcryptjs');
const { User, RefreshToken, Otp } = require('../models');
const { generateAccessToken, generateRefreshToken } = require('../utils/jwt.utils');
const { success, error } = require('../utils/response');
const { REFRESH_EXPIRES_DAYS } = require('../config/jwt');
const { sendSms } = require('../utils/sms.utils');

const SALT_ROUNDS = 12;
const OTP_TTL_MS  = 5 * 60 * 1000;

// Development bypass: accept ANY 6-digit OTP for a valid Indian mobile number,
// so the app can be demoed before Twilio/DLT are live. The number itself is
// still validated (validators/auth.validator.js). Must stay false in production.
const DEV_OTP_BYPASS = process.env.OTP_DEV_BYPASS === 'true';

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

/**
 * Placeholder user for a mobile we haven't seen before.
 * name is NOT NULL, so it holds a temporary value until complete-registration.
 */
async function findOrCreateUser(mobile) {
  const [user] = await User.findOrCreate({
    where: { mobile },
    defaults: {
      name: 'User',
      mobile,
      password_hash: await bcrypt.hash(mobile + Date.now(), SALT_ROUNDS),
      is_active: true,
      is_verified: false,
    },
  });
  return user;
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

    await findOrCreateUser(mobile);

    const otp = generateOtp();
    await Otp.upsert({
      mobile,
      otp,
      expires_at:  new Date(Date.now() + OTP_TTL_MS),
      is_verified: false,
    });

    if (DEV_OTP_BYPASS) {
      console.log(`[OTP] mobile=${mobile}  any 6-digit code will be accepted (OTP_DEV_BYPASS)`);
      return success(res, 'OTP sent successfully.');
    }

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

    if (DEV_OTP_BYPASS) {
      // Any 6-digit code passes; the mobile number was already validated.
      await findOrCreateUser(mobile);
      await Otp.upsert({
        mobile,
        otp:         String(otp),
        expires_at:  new Date(Date.now() + OTP_TTL_MS),
        is_verified: true,
      });
    } else {
      const stored = await Otp.findOne({ where: { mobile } });
      if (!stored || stored.otp !== String(otp) || Date.now() > new Date(stored.expires_at).getTime()) {
        return error(res, 'Invalid or expired OTP.', 401);
      }
      // Mark verified so complete-registration can proceed without re-sending OTP
      await stored.update({ is_verified: true });
    }

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
    await Otp.destroy({ where: { mobile } });
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

    const stored = await Otp.findOne({ where: { mobile } });
    if (!stored?.is_verified) {
      return error(res, 'OTP not verified for this mobile. Please verify OTP first.', 403);
    }

    // Find the placeholder user created during sendOtp
    let user = await User.findOne({ where: { mobile, deleted_at: null } });
    if (!user) return error(res, 'User not found. Please request OTP again.', 404);

    await Otp.destroy({ where: { mobile } });

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
