const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const swaggerSpec = require('./config/swagger');
const routes = require('./routes');
const { notFound, errorHandler } = require('./middleware/error');

const app = express();

// Security headers
app.use(helmet());

// CORS
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

// An empty list or a literal '*' means allow every origin.
const allowAllOrigins = allowedOrigins.length === 0 || allowedOrigins.includes('*');

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowAllOrigins || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    credentials: true,
  })
);

// Serve uploaded files as static
app.use("/uploads", require("express").static(require("path").join(process.cwd(), "uploads")));

// Body parsers
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// Global rate limiter
app.use(
  rateLimit({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
    max: parseInt(process.env.RATE_LIMIT_MAX) || 100,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, message: 'Too many requests, please try again later.' },
  })
);

// ── Swagger docs ──────────────────────────────────────────────────────────────
// The UI is loaded from a CDN rather than swagger-ui-express: serverless
// bundlers drop swagger-ui-dist's static assets, which leaves the page blank.
const SWAGGER_CDN = 'https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.17.14';

app.get('/api-docs.json', (_req, res) => res.json(swaggerSpec));

app.get('/api-docs', (_req, res) => {
  res.setHeader(
    'Content-Security-Policy',
    [
      "default-src 'self'",
      // Trailing slash matters: without it CSP requires an exact path match and
      // blocks every file under the directory.
      `style-src 'self' 'unsafe-inline' ${SWAGGER_CDN}/`,
      `script-src 'self' 'unsafe-inline' ${SWAGGER_CDN}/`,
      "img-src 'self' data:",
      "connect-src 'self'",
    ].join('; ')
  );
  res.type('html').send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Playsher API</title>
  <link rel="stylesheet" href="${SWAGGER_CDN}/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="${SWAGGER_CDN}/swagger-ui-bundle.js"></script>
  <script>
    window.ui = SwaggerUIBundle({
      url: '/api-docs.json',
      dom_id: '#swagger-ui',
      persistAuthorization: true,
    });
  </script>
</body>
</html>`);
});

// API routes
app.use('/api/v1', routes);

// Root route (hosting panel health check expects JSON on GET /)
app.get('/', (_req, res) => res.json({ success: true, message: 'Playsher API is running.' }));

// Health check
app.get('/health', (_req, res) => res.json({ success: true, message: 'Playsher API is running.' }));

// Error handlers
app.use(notFound);
app.use(errorHandler);

module.exports = app;
