/**
 * Vercel serverless entry point.
 *
 * Vercel never calls server.js — it imports this handler per request, so there
 * is no app.listen() and no sequelize.sync(); the schema is applied by running
 * the SQL in database/ against the host manually. `npm start` (server.js) is
 * still the entry point for any host that runs a long-lived process.
 */
require('dotenv').config();

module.exports = require('../src/app');
