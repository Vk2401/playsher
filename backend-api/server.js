require('dotenv').config();
const app = require('./src/app');
const { sequelize } = require('./src/models');

const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await sequelize.authenticate();
    console.log('Database connection established.');

    // No sequelize.sync(). It was here to create missing tables outside
    // production, but on MariaDB it re-issues the UNIQUE constraint behind every
    // `unique: true` attribute on *every* boot, and the server has no way to
    // match it to the index already there — so each start left another copy
    // behind. That is measurable: one restart of this file took the database
    // from 124 indexes to 133, and `users.email` alone is now backed by eight
    // identical unique indexes. MySQL caps a table at 64, so this was a slow
    // walk towards DDL failing outright on users, admins and ground_owners. It
    // also renumbered every foreign key on the way past.
    //
    // Schema is now declared in database/schema.json and applied deliberately
    // from the admin panel (Database → Schema), which only ever adds what is
    // missing. See CLAUDE.md §6.

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
