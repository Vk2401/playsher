/**
 * Turns normalised column/index/table definitions from `database/schema.json`
 * into MariaDB DDL fragments.
 *
 * Kept apart from the diff so the diff reasons about *shape* and this file is
 * the only place that knows SQL syntax. Identifiers are backtick-quoted after
 * being validated against a strict pattern — these names come from a JSON file
 * an admin can edit, so they are treated as untrusted input even though the
 * endpoint is admin-only.
 */

const IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*$/;

/** Numeric types that carry a display width rather than a length. */
const INTEGER_TYPES = ['tinyint', 'smallint', 'mediumint', 'int', 'bigint'];
/** Types whose size is precision + scale. */
const DECIMAL_TYPES = ['decimal', 'numeric', 'float', 'double'];
/** Types that take no size at all. */
const SIZELESS_TYPES = ['text', 'tinytext', 'mediumtext', 'longtext', 'blob', 'longblob',
  'date', 'datetime', 'timestamp', 'time', 'year', 'json', 'boolean'];

const ALL_TYPES = [...INTEGER_TYPES, ...DECIMAL_TYPES, ...SIZELESS_TYPES,
  'varchar', 'char', 'enum', 'set'];

function quoteIdentifier(name) {
  if (!IDENTIFIER.test(String(name))) {
    throw new Error(`Invalid identifier in schema: "${name}".`);
  }
  return `\`${name}\``;
}

function quoteString(value) {
  return `'${String(value).replace(/\\/g, '\\\\').replace(/'/g, "''")}'`;
}

/**
 * Renders the type portion of a column definition — `VARCHAR(150)`,
 * `DECIMAL(10,2)`, `INT UNSIGNED`, `ENUM('a','b')`.
 */
function renderType(column) {
  const type = String(column.type || '').toLowerCase();
  if (!ALL_TYPES.includes(type)) {
    throw new Error(`Unsupported column type "${column.type}".`);
  }

  let sql = type.toUpperCase();

  if (type === 'enum' || type === 'set') {
    if (!Array.isArray(column.values) || !column.values.length) {
      throw new Error(`Column type ${type} requires a non-empty "values" array.`);
    }
    sql += `(${column.values.map(quoteString).join(',')})`;
  } else if (DECIMAL_TYPES.includes(type)) {
    if (column.precision === undefined) {
      throw new Error(`Column type ${type} requires "precision".`);
    }
    sql += `(${column.precision},${column.scale ?? 0})`;
  } else if (type === 'varchar' || type === 'char') {
    if (column.length === undefined) {
      throw new Error(`Column type ${type} requires "length".`);
    }
    sql += `(${column.length})`;
  } else if (INTEGER_TYPES.includes(type) && column.length !== undefined) {
    sql += `(${column.length})`;
  }

  if (column.unsigned) sql += ' UNSIGNED';
  return sql;
}

/** Renders a default value as a SQL literal or expression. */
function renderDefault(column) {
  const value = column.default;
  if (value === undefined || value === null) return null;
  if (typeof value === 'object' && value.expression) return value.expression;
  if (typeof value === 'number') return String(value);
  if (typeof value === 'boolean') return value ? '1' : '0';
  return quoteString(value);
}

/**
 * Renders one full column definition for CREATE TABLE / ADD COLUMN /
 * MODIFY COLUMN. All three need identical output, which is why the engine
 * never hand-builds a fragment anywhere else.
 */
function renderColumnDefinition(name, column) {
  const parts = [quoteIdentifier(name), renderType(column)];

  parts.push(column.nullable === false ? 'NOT NULL' : 'NULL');

  const defaultSql = renderDefault(column);
  if (defaultSql !== null) parts.push(`DEFAULT ${defaultSql}`);

  if (column.onUpdateCurrentTimestamp) parts.push('ON UPDATE CURRENT_TIMESTAMP');
  if (column.autoIncrement) parts.push('AUTO_INCREMENT');

  return parts.join(' ');
}

function renderIndexDefinition(name, index) {
  const columns = index.columns.map(quoteIdentifier).join(', ');
  const kind = index.unique ? 'UNIQUE KEY' : 'KEY';
  return `${kind} ${quoteIdentifier(name)} (${columns})`;
}

function renderForeignKeyDefinition(name, fk) {
  const columns = fk.columns.map(quoteIdentifier).join(', ');
  const refColumns = fk.references.columns.map(quoteIdentifier).join(', ');
  let sql = `CONSTRAINT ${quoteIdentifier(name)} FOREIGN KEY (${columns}) `
    + `REFERENCES ${quoteIdentifier(fk.references.table)} (${refColumns})`;
  if (fk.onDelete) sql += ` ON DELETE ${sanitiseReferentialAction(fk.onDelete)}`;
  if (fk.onUpdate) sql += ` ON UPDATE ${sanitiseReferentialAction(fk.onUpdate)}`;
  return sql;
}

function sanitiseReferentialAction(action) {
  const allowed = ['CASCADE', 'SET NULL', 'RESTRICT', 'NO ACTION', 'SET DEFAULT'];
  const upper = String(action).toUpperCase();
  if (!allowed.includes(upper)) {
    throw new Error(`Invalid referential action "${action}".`);
  }
  return upper;
}

/** Full CREATE TABLE for a table that does not exist yet. */
function renderCreateTable(tableName, table) {
  const lines = Object.entries(table.columns)
    .map(([name, column]) => `  ${renderColumnDefinition(name, column)}`);

  if (table.primaryKey && table.primaryKey.length) {
    lines.push(`  PRIMARY KEY (${table.primaryKey.map(quoteIdentifier).join(', ')})`);
  }
  for (const [name, index] of Object.entries(table.indexes || {})) {
    lines.push(`  ${renderIndexDefinition(name, index)}`);
  }
  // Foreign keys are deliberately left out and added afterwards, as their own
  // ALTER steps. A CREATE TABLE carrying an FK can only run once its referenced
  // table exists, which would make table order significant — and on a fresh
  // database, alphabetical order puts booked_slots before bookings.

  const engine = table.engine || 'InnoDB';
  const charset = table.charset || 'utf8mb4';
  // IF NOT EXISTS so a re-run after a partly-failed sync is harmless, and so the
  // job table can bootstrap itself before appearing in its own plan.
  return `CREATE TABLE IF NOT EXISTS ${quoteIdentifier(tableName)} (\n${lines.join(',\n')}\n) `
    + `ENGINE=${/^[A-Za-z]+$/.test(engine) ? engine : 'InnoDB'} `
    + `DEFAULT CHARSET=${/^[A-Za-z0-9]+$/.test(charset) ? charset : 'utf8mb4'}`;
}

module.exports = {
  quoteIdentifier,
  quoteString,
  renderType,
  renderDefault,
  renderColumnDefinition,
  renderIndexDefinition,
  renderForeignKeyDefinition,
  renderCreateTable,
  INTEGER_TYPES,
  DECIMAL_TYPES,
};
