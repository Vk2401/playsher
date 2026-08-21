#!/usr/bin/env node
/**
 * Seeds `grounds.price_per_slot` from the per-sport prices it replaces.
 *
 * Pricing moved from `ground_sports.price_per_half_hour` to the venue. Adding
 * the column defaults every row to 0, and a venue priced at 0 cannot be booked,
 * so the figures that were already entered need carrying up.
 *
 * Takes the **highest** non-zero price across the venue's sports. A ground that
 * charged 200 for tennis and 100 for cricket becomes 200, not 100: too high is
 * visible and gets corrected, whereas too low silently loses money on every
 * booking. Grounds with no priced sport are left at 0 for their owner to set.
 *
 * Idempotent — only touches rows still at 0, so re-running never overwrites a
 * price someone has since set by hand.
 *
 * Usage: node database/backfill-ground-price.js [--dry-run]
 */

require('dotenv').config();

const sequelize = require('../src/config/database');

(async () => {
  const dryRun = process.argv.includes('--dry-run');

  const candidates = await sequelize.query(
    `SELECT g.id, g.name, g.price_per_slot AS current,
            MAX(gs.price_per_half_hour) AS legacy
       FROM grounds g
       LEFT JOIN ground_sports gs ON gs.ground_id = g.id
      WHERE g.price_per_slot = 0
      GROUP BY g.id, g.name, g.price_per_slot
      ORDER BY g.id`,
    { type: sequelize.QueryTypes.SELECT }
  );

  const toSet = candidates.filter((row) => Number(row.legacy) > 0);
  const leaveAlone = candidates.filter((row) => !(Number(row.legacy) > 0));

  console.log(`${candidates.length} ground(s) still at 0.`);

  for (const row of toSet) {
    console.log(`  #${row.id} ${row.name} → ${Number(row.legacy).toFixed(2)}`);
    if (!dryRun) {
      await sequelize.query(
        'UPDATE grounds SET price_per_slot = :price WHERE id = :id AND price_per_slot = 0',
        { replacements: { price: Number(row.legacy), id: row.id } }
      );
    }
  }

  for (const row of leaveAlone) {
    console.log(`  #${row.id} ${row.name} → left at 0; the owner must set a price `
      + 'before it can be booked');
  }

  console.log(dryRun
    ? '\nDry run — nothing written.'
    : `\nUpdated ${toSet.length} ground(s).`);

  await sequelize.close();
})().catch((err) => {
  console.error(`Failed: ${err.message}`);
  process.exit(1);
});
