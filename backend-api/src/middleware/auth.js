const { verifyToken } = require('../utils/jwt.utils');
const { error } = require('../utils/response');

/**
 * Middleware: extract and verify Bearer JWT from Authorization header.
 * Attaches decoded payload to req.user = { id, role }.
 */
function verifyTokenMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return error(res, 'Authorization token required.', 401);
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = verifyToken(token);
    req.user = { id: decoded.id, role: decoded.role };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return error(res, 'Token has expired.', 401);
    }
    return error(res, 'Invalid token.', 401);
  }
}

/**
 * Middleware factory: allow only specific roles.
 * Usage: requireRole('admin') or requireRole('admin', 'ground_owner')
 */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return error(res, 'Not authenticated.', 401);
    if (!roles.includes(req.user.role)) {
      return error(res, 'Forbidden: insufficient privileges.', 403);
    }
    next();
  };
}

/**
 * Middleware: read the Bearer token when there is one, and carry on either way.
 *
 * For endpoints that are public but answer *better* to someone signed in — the
 * games feed, which marks the ones you are already playing in and the ones you
 * host. A missing, malformed or expired token leaves `req.user` undefined
 * rather than answering 401, so a logged-out player still gets the feed.
 * Never use this to guard a write.
 */
function optionalAuth(req, _res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) return next();
  try {
    const decoded = verifyToken(authHeader.split(' ')[1]);
    req.user = { id: decoded.id, role: decoded.role };
  } catch {
    // A bad token on a public route is the same as no token.
  }
  return next();
}

module.exports = { verifyToken: verifyTokenMiddleware, requireRole, optionalAuth };
