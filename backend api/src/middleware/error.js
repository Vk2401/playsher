/**
 * 404 handler — attach after all routes.
 */
function notFound(req, res) {
  res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found.` });
}

/**
 * Global error handler — attach last.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  console.error(err);
  const statusCode = err.statusCode || err.status || 500;
  res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal server error.',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
}

module.exports = { notFound, errorHandler };
