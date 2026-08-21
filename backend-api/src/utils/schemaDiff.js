/**
 * Compares `database/schema.json` (what the schema should be) against the live
 * database (what it is) and produces an ordered, classified list of operations.
 *
 * ── The safety rule this file exists to enforce ──────────────────────────────
 * Nothing here ever destroys data. There is no code path that emits DROP TABLE,
 * DROP COLUMN or TRUNCATE — not behind a flag, not with a confirmation. A table
 * or column that exists live but is absent from the JSON is reported as an
 * `extras` note for a human to deal with by hand, never as an operation.
 *
 * Each operation carries a `risk`:
 *
 *   safe    Cannot lose data and cannot fail on existing rows. Applied by
 *           default: CREATE TABLE, ADD COLUMN (nullable, or NOT NULL with a
 *           default), ADD INDEX, ADD FOREIGN KEY, widening a column, relaxing
 *           NOT NULL to NULL, changing a default, appending enum values.
 *
 *   risky   Succeeds, but changes or constrains existing values: narrowing a
 *           column, removing enum values, or tightening NULL to NOT NULL (which
 *           first backfills NULLs with the schema default). Requires the admin
 *           to opt in explicitly — a second checkbox, not the main button.
 *
 *   blocked Cannot be applied safely at all, with the reason attached. Never
 *           executed. Reported so the admin can see why the DB and the JSON
 *           still disagree rather than being told everything is in sync.
 */

const {
  quoteIdentifier,
  renderColumnDefinition,
  renderIndexDefinition,
  renderForeignKeyDefinition,
  renderCreateTable,
  renderDefault,
  INTEGER_TYPES,
  DECIMAL_TYPES,
} = require('./schemaDdl');

/** Text types ordered by capacity, so a widening move can be recognised. */
const TEXT_RANK = { tinytext: 1, text: 2, mediumtext: 3, longtext: 4 };
const INT_RANK = { tinyint: 1, smallint: 2, mediumint: 3, int: 4, bigint: 5 };

/**
 * Is the desired column at least as capacious as the live one? A widening
 * change keeps every existing value intact; a narrowing one can truncate.
 */
function isWidening(desired, live) {
  const from = String(live.type).toLowerCase();
  const to = String(desired.type).toLowerCase();

  if (from === to) {
    if (to === 'varchar' || to === 'char') {
      return (desired.length ?? 0) >= (live.length ?? 0);
    }
    if (DECIMAL_TYPES.includes(to)) {
      const precisionGrew = (desired.precision ?? 0) >= (live.precision ?? 0);
      const scaleKept = (desired.scale ?? 0) >= (live.scale ?? 0);
      // Growing the integer part matters as much as the precision total.
      const integerDigitsKept = (desired.precision ?? 0) - (desired.scale ?? 0)
        >= (live.precision ?? 0) - (live.scale ?? 0);
      return precisionGrew && scaleKept && integerDigitsKept;
    }
    if (INTEGER_TYPES.includes(to)) {
      // Display width is cosmetic; dropping UNSIGNED halves the positive range
      // but keeps every stored value representable.
      return true;
    }
    return true;
  }

  if (TEXT_RANK[from] && TEXT_RANK[to]) return TEXT_RANK[to] >= TEXT_RANK[from];
  if (INT_RANK[from] && INT_RANK[to]) return INT_RANK[to] >= INT_RANK[from];
  // varchar → text always fits.
  if ((from === 'varchar' || from === 'char') && TEXT_RANK[to]) return true;
  return false;
}

/**
 * Compares two normalised columns for the fields that affect DDL.
 *
 * Integer display width is excluded on purpose. `INT(10)` and `INT` are the same
 * column — the width only ever affected ZEROFILL padding — and MySQL 8.0.19
 * removed it from `information_schema` altogether. Comparing it makes every
 * integer column look permanently out of date on MySQL while matching on
 * MariaDB, which is a diff that can never be resolved by applying it.
 */
function columnDiffers(desired, live) {
  const isInteger = INTEGER_TYPES.includes(String(desired.type ?? '').toLowerCase());
  const fields = ['type', 'precision', 'scale', 'unsigned', 'nullable',
    'autoIncrement', 'onUpdateCurrentTimestamp'];
  if (!isInteger) fields.push('length');

  for (const field of fields) {
    const a = normaliseField(desired[field], field);
    const b = normaliseField(live[field], field);
    if (a !== b) return true;
  }

  if (JSON.stringify(desired.values ?? null) !== JSON.stringify(live.values ?? null)) {
    return true;
  }
  return normaliseDefault(desired) !== normaliseDefault(live);
}

/**
 * Renders a default for comparison only. Expression defaults are folded to a
 * single spelling because the server echoes them back inconsistently —
 * `current_timestamp()` on MariaDB, `CURRENT_TIMESTAMP` on MySQL — and a
 * spelling difference is not a schema difference.
 */
function normaliseDefault(column) {
  const rendered = renderDefault(column);
  if (rendered === null) return null;
  return String(rendered).toLowerCase().replace(/\(\s*\)/g, '');
}

function normaliseField(value, field) {
  if (field === 'unsigned' || field === 'autoIncrement' || field === 'onUpdateCurrentTimestamp') {
    return value === true;
  }
  if (field === 'nullable') return value !== false;
  if (field === 'type') return String(value ?? '').toLowerCase();
  // A missing display width and an explicit one mean the same thing for ints.
  return value === undefined ? null : value;
}

/**
 * Classifies a column change and, when it needs one, attaches the backfill that
 * makes it safe to run against rows that already exist.
 */
function classifyColumnChange(tableName, columnName, desired, live) {
  const reasons = [];
  let risk = 'safe';
  const preSteps = [];

  if (!isWidening(desired, live)) {
    risk = 'risky';
    reasons.push(`narrows ${live.type}${live.length ? `(${live.length})` : ''} `
      + `to ${desired.type}${desired.length ? `(${desired.length})` : ''}, `
      + 'which can truncate existing values');
  }

  if (desired.type === 'enum' && live.type === 'enum') {
    const removed = (live.values || []).filter((v) => !(desired.values || []).includes(v));
    if (removed.length) {
      risk = 'risky';
      reasons.push(`removes enum value(s) ${removed.map((v) => `"${v}"`).join(', ')} — `
        + 'rows holding them become empty');
    }
  }

  // Tightening nullability is the one change that can fail outright on existing
  // data. With a default we can fill the NULLs first and keep every row.
  if (desired.nullable === false && live.nullable !== false) {
    const defaultSql = renderDefault(desired);
    if (defaultSql === null) {
      return {
        risk: 'blocked',
        reason: `${tableName}.${columnName} becomes NOT NULL but the schema gives no `
          + 'default, so existing NULL rows could not be filled. Add a "default" to '
          + 'this column in schema.json.',
      };
    }
    risk = 'risky';
    reasons.push('tightens NULL to NOT NULL — existing NULL rows are backfilled with '
      + `the default (${defaultSql})`);
    preSteps.push({
      description: `Backfill NULLs in ${tableName}.${columnName} with ${defaultSql}`,
      sql: `UPDATE ${quoteIdentifier(tableName)} SET ${quoteIdentifier(columnName)} = ${defaultSql} `
        + `WHERE ${quoteIdentifier(columnName)} IS NULL`,
    });
  }

  return { risk, reason: reasons.join('; '), preSteps };
}

/**
 * Builds the operation list.
 *
 * Order matters: tables before the columns that live in them, columns before
 * the indexes that reference them, and foreign keys last so both sides of every
 * reference already exist.
 *
 * @param {object} desired parsed schema.json — `{ tables: {...} }`
 * @param {object} live    output of `schemaIntrospect.introspect()`
 * @returns {{operations: Array, extras: Array, blocked: Array}}
 */
function diff(desired, live) {
  const operations = [];
  const extras = [];
  const blocked = [];
  const newTables = new Set();

  const push = (op) => {
    if (op.risk === 'blocked') blocked.push(op);
    else operations.push(op);
  };

  // ── New tables ──────────────────────────────────────────────────────────────
  for (const [tableName, table] of Object.entries(desired.tables)) {
    if (live.tables[tableName]) continue;
    newTables.add(tableName);
    push({
      kind: 'createTable',
      table: tableName,
      risk: 'safe',
      description: `Create table ${tableName} `
        + `(${Object.keys(table.columns).length} columns)`,
      sql: renderCreateTable(tableName, table),
    });
  }

  // ── Existing tables ─────────────────────────────────────────────────────────
  for (const [tableName, table] of Object.entries(desired.tables)) {
    if (newTables.has(tableName)) continue;
    const liveTable = live.tables[tableName];

    // Columns: add missing, modify changed. Never drop.
    const desiredColumnNames = Object.keys(table.columns);
    // Columns added earlier in this same plan do not exist live yet, but they
    // will by the time the next ADD COLUMN runs — so they are valid anchors for
    // an AFTER clause. Without this, a run of new columns all land at the end
    // of the table and the next generated schema.json reorders them.
    const willExist = new Set(Object.keys(liveTable.columns));
    for (const [index, columnName] of desiredColumnNames.entries()) {
      const desiredColumn = table.columns[columnName];
      const liveColumn = liveTable.columns[columnName];

      if (!liveColumn) {
        const defaultSql = renderDefault(desiredColumn);
        if (desiredColumn.nullable === false && defaultSql === null
          && !desiredColumn.autoIncrement) {
          push({
            kind: 'addColumn',
            table: tableName,
            risk: 'blocked',
            description: `Add column ${tableName}.${columnName}`,
            reason: `${tableName}.${columnName} is NOT NULL with no default. Existing rows `
              + 'have no value to take, so MariaDB would fall back to an implicit zero or '
              + 'empty string. Give the column a "default" in schema.json, or make it '
              + 'nullable.',
          });
          continue;
        }

        // Placing the column where the JSON puts it keeps DESCRIBE readable and
        // makes a generated schema.json round-trip cleanly.
        const previous = desiredColumnNames[index - 1];
        const position = index === 0
          ? ' FIRST'
          : (previous && willExist.has(previous) ? ` AFTER ${quoteIdentifier(previous)}` : '');
        willExist.add(columnName);

        push({
          kind: 'addColumn',
          table: tableName,
          risk: 'safe',
          description: `Add column ${tableName}.${columnName} `
            + `(${desiredColumn.type}${defaultSql ? `, default ${defaultSql}` : ''})`,
          sql: `ALTER TABLE ${quoteIdentifier(tableName)} ADD COLUMN `
            + `${renderColumnDefinition(columnName, desiredColumn)}${position}`,
        });
        continue;
      }

      if (!columnDiffers(desiredColumn, liveColumn)) continue;

      const verdict = classifyColumnChange(tableName, columnName, desiredColumn, liveColumn);
      if (verdict.risk === 'blocked') {
        push({
          kind: 'modifyColumn',
          table: tableName,
          risk: 'blocked',
          description: `Modify column ${tableName}.${columnName}`,
          reason: verdict.reason,
        });
        continue;
      }

      push({
        kind: 'modifyColumn',
        table: tableName,
        risk: verdict.risk,
        description: `Modify column ${tableName}.${columnName}`
          + (verdict.reason ? ` — ${verdict.reason}` : ''),
        preSteps: verdict.preSteps,
        sql: `ALTER TABLE ${quoteIdentifier(tableName)} MODIFY COLUMN `
          + `${renderColumnDefinition(columnName, desiredColumn)}`,
      });
    }

    for (const columnName of Object.keys(liveTable.columns)) {
      if (!table.columns[columnName]) {
        extras.push({
          kind: 'extraColumn',
          table: tableName,
          description: `Column ${tableName}.${columnName} exists in the database but not in `
            + 'schema.json. Left untouched — add it to the JSON to keep it, or drop it by '
            + 'hand if it is genuinely dead.',
        });
      }
    }

    // Indexes: add missing only. A live index the JSON omits stays.
    for (const [indexName, index] of Object.entries(table.indexes || {})) {
      const liveIndex = liveTable.indexes[indexName];
      if (liveIndex) {
        const sameColumns = JSON.stringify(liveIndex.columns) === JSON.stringify(index.columns);
        if (!sameColumns || liveIndex.unique !== index.unique) {
          blocked.push({
            kind: 'index',
            table: tableName,
            risk: 'blocked',
            description: `Index ${tableName}.${indexName} differs from schema.json`,
            reason: `live (${liveIndex.columns.join(', ')}${liveIndex.unique ? ', unique' : ''}) `
              + `vs schema (${index.columns.join(', ')}${index.unique ? ', unique' : ''}). `
              + 'Changing an index means dropping it first, which this tool never does. '
              + 'Rename the index in schema.json to add the new one alongside.',
          });
        }
        continue;
      }

      // A UNIQUE index cannot be created over columns that already hold
      // duplicates — flagged so the run does not fail halfway through.
      push({
        kind: 'addIndex',
        table: tableName,
        risk: 'safe',
        description: `Add ${index.unique ? 'unique ' : ''}index ${indexName} on `
          + `${tableName} (${index.columns.join(', ')})`,
        duplicateCheck: index.unique
          ? {
            table: tableName,
            columns: index.columns,
            sql: `SELECT COUNT(*) AS duplicates FROM (SELECT 1 FROM ${quoteIdentifier(tableName)} `
              + `GROUP BY ${index.columns.map(quoteIdentifier).join(', ')} `
              + 'HAVING COUNT(*) > 1) AS d',
          }
          : null,
        sql: `ALTER TABLE ${quoteIdentifier(tableName)} ADD `
          + `${renderIndexDefinition(indexName, index)}`,
      });
    }

    for (const indexName of Object.keys(liveTable.indexes)) {
      if (!(table.indexes || {})[indexName]) {
        extras.push({
          kind: 'extraIndex',
          table: tableName,
          description: `Index ${tableName}.${indexName} exists in the database but not in `
            + 'schema.json. Left untouched.',
        });
      }
    }
  }

  // ── Foreign keys last, once every table and column exists ───────────────────
  for (const [tableName, table] of Object.entries(desired.tables)) {
    const liveTable = live.tables[tableName];
    for (const [fkName, fk] of Object.entries(table.foreignKeys || {})) {
      // Includes brand-new tables: CREATE TABLE omits foreign keys so that this
      // pass, which runs once every table exists, can add them in any order.
      if (liveTable && liveTable.foreignKeys[fkName]) continue;
      push({
        kind: 'addForeignKey',
        table: tableName,
        risk: 'safe',
        description: `Add foreign key ${fkName} on ${tableName} `
          + `(${fk.columns.join(', ')}) → ${fk.references.table}`,
        sql: `ALTER TABLE ${quoteIdentifier(tableName)} ADD `
          + `${renderForeignKeyDefinition(fkName, fk)}`,
      });
    }
  }

  for (const [tableName, liveTable] of Object.entries(live.tables)) {
    if (!desired.tables[tableName]) {
      extras.push({
        kind: 'extraTable',
        table: tableName,
        description: `Table ${tableName} exists in the database but not in schema.json `
          + `(${Object.keys(liveTable.columns).length} columns). Left untouched.`,
      });
    }
  }

  return { operations, extras, blocked };
}

module.exports = { diff, isWidening, columnDiffers };
