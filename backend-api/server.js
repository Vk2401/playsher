require('dotenv').config();
const app = require('./src/app');
const { sequelize } = require('./src/models');

const PORT = process.env.PORT || 3000;

// ── Crash guards ──────────────────────────────────────────────────────────────
// Node kills the process on an unhandled rejection, so one forgotten `await`
// anywhere in a request handler takes the whole API down for every user. Log it
// and keep serving instead — the request that caused it has already failed on
// its own. An uncaught exception leaves the process in an unknown state, so
// that one still exits, but with a readable line in the log first.
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled promise rejection:', reason);
});

process.on('uncaughtException', (err) => {
  console.error('Uncaught exception — exiting:', err);
  process.exit(1);
});

async function start() {
  try {
    await sequelize.authenticate();
    console.log('Database connection established.');

    // Sync models (use migrations in production)
    if (process.env.NODE_ENV !== 'production') {
      await sequelize.sync({ alter: false });
    }

    app.listen(PORT, () => {
      console.log(`Playsher API running on port ${PORT}`);
      console.log(`Swagger docs: http://localhost:${PORT}/api-docs`);
    });
  } catch (err) {
    console.error('Unable to start server:', err);
    process.exit(1);
  }
}

start();
