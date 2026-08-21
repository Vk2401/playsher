const { success, error } = require('../utils/response');
const {
  loadSchema, buildPlan, createJob, getJob, runOperations,
} = require('../utils/schemaSync');

/**
 * Turns a plan into the counts the confirmation dialog needs, so the client
 * does not have to derive them and the two cannot disagree.
 */
function summarise(plan) {
  const safe = plan.operations.filter((op) => op.risk === 'safe');
  const risky = plan.operations.filter((op) => op.risk === 'risky');
  return {
    total: plan.operations.length,
    safe: safe.length,
    risky: risky.length,
    blocked: plan.blocked.length,
    extras: plan.extras.length,
    in_sync: plan.operations.length === 0 && plan.blocked.length === 0,
  };
}

/** Strips the SQL down to what is useful to show, keeping the payload small. */
function presentOperation(op, index) {
  return {
    index,
    kind: op.kind,
    table: op.table,
    risk: op.risk,
    description: op.description,
    sql: op.sql,
    pre_sql: (op.preSteps || []).map((step) => step.sql),
  };
}

// GET /admin/schema
// The definition file itself, for the admin panel to display.
exports.getDefinition = async (req, res) => {
  try {
    const schema = loadSchema();
    const tables = Object.entries(schema.tables).map(([name, table]) => ({
      name,
      columns: Object.keys(table.columns).length,
      indexes: Object.keys(table.indexes || {}).length,
      foreign_keys: Object.keys(table.foreignKeys || {}).length,
    }));

    return success(res, 'Schema definition retrieved.', {
      version: schema.version ?? null,
      table_count: tables.length,
      column_count: tables.reduce((total, t) => total + t.columns, 0),
      tables,
      definition: schema,
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// GET /admin/schema/plan
// Dry run. Never changes anything — this is what the confirmation dialog shows.
exports.getPlan = async (req, res) => {
  try {
    const plan = await buildPlan();
    return success(res, 'Schema plan generated.', {
      summary: summarise(plan),
      operations: plan.operations.map(presentOperation),
      blocked: plan.blocked.map((op) => ({
        kind: op.kind,
        table: op.table,
        description: op.description,
        reason: op.reason,
      })),
      extras: plan.extras,
    });
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// POST /admin/schema/apply
// Starts the sync and returns a job id immediately; the panel polls the job for
// progress. Risky operations are opted into explicitly, never by default.
exports.apply = async (req, res) => {
  try {
    const includeRisky = req.body?.include_risky === true;

    const plan = await buildPlan();
    const operations = plan.operations
      .filter((op) => op.risk === 'safe' || (includeRisky && op.risk === 'risky'));

    if (!operations.length) {
      return success(res, 'Nothing to apply — the database already matches schema.json.', {
        job_id: null,
        summary: summarise(plan),
      });
    }

    const jobId = await createJob(operations, req.user?.id);

    // Deliberately not awaited: the response returns the job id straight away
    // so the panel can start polling, and a long sync does not sit against the
    // request timeout. Failures are recorded on the job row, not thrown here.
    runOperations(jobId, operations).catch(() => { /* recorded on the job row */ });

    return success(res, 'Schema sync started.', {
      job_id: jobId,
      total_steps: operations.length,
      summary: summarise(plan),
    }, 202);
  } catch (err) {
    return error(res, err.message, 500);
  }
};

// GET /admin/schema/jobs/:id
exports.getJobStatus = async (req, res) => {
  try {
    const job = await getJob(req.params.id);
    if (!job) return error(res, 'Sync job not found.', 404);
    return success(res, 'Sync job retrieved.', job);
  } catch (err) {
    return error(res, err.message, 500);
  }
};
