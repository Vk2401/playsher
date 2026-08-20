#!/usr/bin/env node
/**
 * Applies .sql migration files to the database named in .env.
 *
 * The `mysql` CLI cannot reach the managed MariaDB server from a host running
 * MySQL 9.x — the client dropped the `mysql_native_password` plugin the server
 * asks for (ERROR 2059). This runner goes through the same `mysql2` driver the
 * app already uses, so it authenticates the same way Sequelize does.
 *
 * Usage: node database/apply-migrations.js database/migrations/foo.sql [...]
 */
require('dotenv').config();

const fs    = require('fs');
const path  = require('path');
const mysql = require('mysql2/promise');

// Strips comment-only lines, then splits on the `;` that ends each statement.
// Statements here are plain DDL/INSERT — no stored routines, so no DELIMITER
// handling is needed.
const parse = (sql) =>
  sql
    .split('\n')
    .filter((line) => !/^\s*--/.test(line))
    .join('\n')
    .split(/;\s*(?:\r?\n|$)/)
    .map((s) => s.trim())
    .filter(Boolean);

(async () => {
  const files = process.argv.slice(2);
  if (!files.length) {
    console.error('Usage: node database/apply-migrations.js <file.sql> [...]');
    process.exit(1);
  }

  const connection = await mysql.createConnection({
    host:     process.env.DB_HOST,
    port:     Number(process.env.DB_PORT) || 3306,
    user:     process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  console.log(`Connected to ${process.env.DB_NAME} @ ${process.env.DB_HOST}`);

  let failed = 0;

  for (const file of files) {
    console.log(`\n── ${path.basename(file)} ─────────────────────`);

    for (const statement of parse(fs.readFileSync(file, 'utf8'))) {
      const label = statement.replace(/\s+/g, ' ').slice(0, 72);
      try {
        await connection.query(statement);
        console.log(`  ok   ${label}`);
      } catch (err) {
        failed += 1;
        console.log(`  FAIL ${label}\n       ${err.message}`);
      }
    }
  }

  await connection.end();
  console.log(failed ? `\n${failed} statement(s) failed.` : '\nAll statements applied.');
  process.exit(failed ? 1 : 0);
})().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
