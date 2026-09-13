#!/usr/bin/env node
/**
 * Gives a handle to every account that does not have one.
 *
 * `users.username` arrived after the app did. Registration assigns one and
 * signing in backfills one, but an account that has done neither since is left
 * with NULL — and a player with no handle has nothing under their name in a
 * search result but the name itself. Three accounts called "Vasanth" then
 * render as three identical rows, which reads as duplicate records rather than
 * as three different people.
 *
 * One handle at a time rather than a single UPDATE: each name has to be checked
 * against the ones already taken, and the unique index is the arbiter — a
 * collision is retried rather than failing the run.
 *
 * Idempotent. Only touches rows where `username IS NULL` or is blank, so
 * re-running never renames anybody.
 *
 * Usage: node database/backfill-usernames.js [--dry-run]
 */

require('dotenv').config();

const { User } = require('../src/models');
const sequelize = require('../src/config/database');
const { generateUniqueUsername, isUsernameConflict } = require('../src/utils/username');

const { Op } = require('sequelize');

(async () => {
  const dryRun = process.argv.includes('--dry-run');

  const rows = await User.findAll({
    where: {
      deleted_at: null,
      [Op.or]: [{ username: null }, { username: '' }],
    },
    attributes: ['id', 'name', 'mobile'],
    order: [['id', 'ASC']],
  });

  console.log(`${rows.length} account(s) without a handle.`);

  let written = 0;
  let failed  = 0;

  for (const row of rows) {
    // eslint-disable-next-line no-await-in-loop
    const candidate = await generateUniqueUsername(User);
    console.log(`  #${row.id} ${row.name || '(no name)'} → @${candidate}`);
    if (dryRun) continue;

    try {
      // eslint-disable-next-line no-await-in-loop
      await User.update({ username: candidate }, { where: { id: row.id } });
      written += 1;
    } catch (err) {
      if (!isUsernameConflict(err)) throw err;
      // Lost the race to another writer. One more roll, then leave it for the
      // next run rather than spinning on a name nobody has seen.
      try {
        // eslint-disable-next-line no-await-in-loop
        await User.update({ username: await generateUniqueUsername(User) }, { where: { id: row.id } });
        written += 1;
      } catch {
        console.warn(`  #${row.id} skipped — handle taken twice in a row`);
        failed += 1;
      }
    }
  }

  console.log(dryRun
    ? '\nDry run — nothing written.'
    : `\nAssigned ${written} handle(s)${failed ? `, ${failed} left for the next run` : ''}.`);

  await sequelize.close();
})().catch((err) => {
  console.error(`Failed: ${err.message}`);
  process.exit(1);
});
