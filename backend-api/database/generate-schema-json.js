#!/usr/bin/env node
/**
 * Regenerates `database/schema.json` from whatever database `.env` points at.
 *
 * This is a one-way capture tool, used to seed the file from an existing
 * database (as it was when the JSON was first introduced) or to re-sync it
 * after someone has changed the schema by hand. Day to day the JSON is the
 * source of truth and is edited directly — see CLAUDE.md.
 *
 * Usage: node database/generate-schema-json.js [--out path] [--stdout]
 */

require('dotenv').config();

const fs = require('fs');
const path = require('path');

const sequelize = require('../src/config/database');
const { introspect } = require('../src/utils/schemaIntrospect');

const HEADER_COMMENT = 'Generated from a live database by '
  + 'database/generate-schema-json.js. Edit this file to change the schema, then '
  + 'apply it from the admin panel (Database → Schema).';

(async () => {
  const args = process.argv.slice(2);
  const outIndex = args.indexOf('--out');
  const outPath = outIndex !== -1
    ? path.resolve(args[outIndex + 1])
    : path.join(__dirname, 'schema.json');

  const live = await introspect();
  const tableNames = Object.keys(live.tables).sort();

  const document = {
    $comment: HEADER_COMMENT,
    version: 1,
    tables: {},
  };
  for (const name of tableNames) document.tables[name] = live.tables[name];

  const json = `${JSON.stringify(document, null, 2)}\n`;

  if (args.includes('--stdout')) {
    process.stdout.write(json);
  } else {
    fs.writeFileSync(outPath, json);
    const columnCount = tableNames
      .reduce((total, name) => total + Object.keys(live.tables[name].columns).length, 0);
    console.log(`Wrote ${outPath}`);
    console.log(`  ${tableNames.length} tables, ${columnCount} columns`);
  }

  await sequelize.close();
})().catch((err) => {
  console.error(`Failed: ${err.message}`);
  process.exit(1);
});
