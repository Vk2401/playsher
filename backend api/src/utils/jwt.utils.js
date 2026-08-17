const jwt = require('jsonwebtoken');
const { JWT_SECRET, ACCESS_EXPIRES_IN, REFRESH_EXPIRES_IN } = require('../config/jwt');

/**
 * Generate a short-lived access token.
 * @param {object} payload  Must include { id, role }
 */
function generateAccessToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { algorithm: 'HS256', expiresIn: ACCESS_EXPIRES_IN });
}

/**
 * Generate a long-lived refresh token.
 * @param {object} payload  Must include { id, role }
 */
function generateRefreshToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { algorithm: 'HS256', expiresIn: REFRESH_EXPIRES_IN });
}

/**
 * Verify and decode a JWT.
 * @throws {JsonWebTokenError|TokenExpiredError}
 */
function verifyToken(token) {
  return jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
}

module.exports = { generateAccessToken, generateRefreshToken, verifyToken };
