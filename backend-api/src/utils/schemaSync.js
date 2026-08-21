/**
 * Applies the operation list from `schemaDiff` to the live database, recording
 * progress as it goes so the admin panel can follow along.
 *
 * Progress is kept in the `schema_sync_jobs` table rather than in memory. The
 * API can run as several processes (and as short-lived serverless instances),
 * so an in-memory job would be invisible to the request that polls for it —
 * the same reason OTPs moved out of memory and into a table. The job table is
 * bootstrapped with a plain CREATE TABLE IF NOT EXISTS before any run, because
 * it has to exist before the very first sync can report on itself.
 */

const fs = require('fs');
const path = require('path');

const sequelize = require('../config/database');
const { introspect } = require('./schemaIntrospect');
const { diff } = require('./schemaDiff');

const SCHEMA_PATH = path.join(__dirname, '..', '..', 'database', 'schema.json');

const JOB_TABLE_DDL = `
  CREATE TABLE IF NOT EXISTS schema_sync_jobs (
    id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    status          ENUM('running','completed','failed') NOT NULL DEFAULT 'running',
    total_steps     INT UNSIGNED NOT NULL DEFAULT 0,
    completed_steps INT UNSIGNED NOT NULL DEFAULT 0,
    current_step    VARCHAR(500) DEFAULT NULL,
    steps           LONGTEXT DEFAULT NULL,
    error_message   TEXT DEFAULT NULL,
    started_by      INT UNSIGNED DEFAULT NULL,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
`;

/** Reads and sanity-checks `database/schema.json`. */
function loadSchema() {
  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(SCHEMA_PATH, 'utf8'));
  } catch (err) {
    throw new Error(`Could not read database/schema.json: ${err.message}`);
  }

  if (!parsed || typeof parsed.tables !== 'object' || !Object.keys(parsed.tables).length) {
    throw new Error('schema.json must contain a non-empty "tables" object.');
  }

  for (const [tableName, table] of Object.entries(parsed.tables)) {
    if (!table.columns || !Object.keys(table.columns).length) {
      throw new Error(`Table "${tableName}" in schema.json has no columns.`);
    }
    for (const [columnName, column] of Object.entries(table.columns)) {
      if (!column.type) {
        throw new Error(`Column "${tableName}.${columnName}" in schema.json has no "type".`);
      }
    }
  }
  return parsed;
}

/**
 * Works out what would change, without touching anything.
 * @returns {Promise<{operations: Array, extras: Array, blocked: Array, schemaVersion: *}>}
 */
async function buildPlan() {
  const desired = loadSchema();
  const live = await introspect();
  const result = diff(desired, live);
  return { ...result, schemaVersion: desired.version ?? null };
}

async function ensureJobTable() {
  await sequelize.query(JOB_TABLE_DDL);
}

async function createJob(operations, adminId) {
  await ensureJobTable();
  const steps = operations.map((op) => ({
    description: op.description,
    risk: op.risk,
    status: 'pending',
  }));

  const [id] = await sequelize.query(
    `INSERT INTO schema_sync_jobs (status, total_steps, completed_steps, steps, started_by)
     VALUES ('running', :total, 0, :steps, :adminId)`,
    { replacements: { total: operations.length, steps: JSON.stringify(steps), adminId: adminId ?? null } }
  );
  return id;
}

async function updateJob(jobId, fields) {
  const assignments = Object.keys(fields).map((key) => `${key} = :${key}`).join(', ');
  await sequelize.query(
    `UPDATE schema_sync_jobs SET ${assignments} WHERE id = :jobId`,
    { replacements: { ...fields, jobId } }
  );
}

/** Reads a job back for the polling endpoint. */
async function getJob(jobId) {
  await ensureJobTable();
  const rows = await sequelize.query(
    'SELECT * FROM schema_sync_jobs WHERE id = :jobId',
    { replacements: { jobId }, type: sequelize.QueryTypes.SELECT }
  );
  if (!rows.length) return null;

  const job = rows[0];
  let steps = [];
  try {
    steps = job.steps ? JSON.parse(job.steps) : [];
  } catch {
    steps = [];
  }

  return {
    id: job.id,
    status: job.status,
    total_steps: job.total_steps,
    completed_steps: job.completed_steps,
    current_step: job.current_step,
    error_message: job.error_message,
    percent: job.total_steps ? Math.round((job.completed_steps / job.total_steps) * 100) : 100,
    steps,
    created_at: job.created_at,
    updated_at: job.updated_at,
  };
}

/**
 * Runs the operations in order, updating the job row after each one.
 *
 * Deliberately not wrapped in a transaction: MariaDB gives no transactional
 * DDL, so a rollback would be a lie. Instead each step is independent and
 * ordered so that a failure leaves the schema in a valid intermediate state,
 * and the job row records exactly which step stopped it. Re-running picks up
 * from there, because every remaining operation is derived from a fresh diff.
 */
async function runOperations(jobId, operations) {
  const steps = operations.map((op) => ({
    description: op.description,
    risk: op.risk,
    status: 'pending',
  }));

  let completed = 0;

  for (const [index, op] of operations.entries()) {
    steps[index].status = 'running';
    await updateJob(jobId, {
      current_step: op.description.slice(0, 500),
      completed_steps: completed,
      steps: JSON.stringify(steps),
    });

    try {
      // A unique index over existing duplicates would fail — check first so the
      // step is skipped with a clear reason instead of aborting the whole run.
      if (op.duplicateCheck) {
        const rows = await sequelize.query(op.duplicateCheck.sql, {
          type: sequelize.QueryTypes.SELECT,
        });
        if (Number(rows[0]?.duplicates || 0) > 0) {
          steps[index].status = 'skipped';
          steps[index].message = `${rows[0].duplicates} duplicate group(s) already exist in `
            + `${op.duplicateCheck.table} (${op.duplicateCheck.columns.join(', ')}), so a unique `
            + 'index cannot be created. Resolve the duplicates, then sync again.';
          completed += 1;
          continue;
        }
      }

      for (const pre of op.preSteps || []) {
        await sequelize.query(pre.sql);
      }
      await sequelize.query(op.sql);

      steps[index].status = 'done';
      completed += 1;
    } catch (err) {
      steps[index].status = 'failed';
      steps[index].message = err.message;
      await updateJob(jobId, {
        status: 'failed',
        completed_steps: completed,
        current_step: null,
        steps: JSON.stringify(steps),
        error_message: `Step ${index + 1} of ${operations.length} failed: ${err.message}`,
      });
      return;
    }
  }

  await updateJob(jobId, {
    status: 'completed',
    completed_steps: completed,
    current_step: null,
    steps: JSON.stringify(steps),
  });
}

module.exports = {
  SCHEMA_PATH,
  loadSchema,
  buildPlan,
  ensureJobTable,
  createJob,
  getJob,
  runOperations,
};
