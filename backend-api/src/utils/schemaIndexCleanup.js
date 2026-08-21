/**
 * The one place in the schema tooling that drops anything.
 *
 * `schemaDiff` never emits a DROP, deliberately — a column or table missing
 * from the JSON might be something nobody has declared yet, and guessing costs
 * data. A *duplicate index* is different: it is provably redundant. If two
 * indexes cover the same columns in the same order with the same uniqueness,
 * one of them enforces and accelerates exactly nothing that the other does not
 * already, so removing it cannot change a query result, cannot weaken a
 * constraint, and cannot lose a row.
 *
 * They exist because `sequelize.sync()` re-issued the UNIQUE constraint behind
 * every `unique: true` attribute on each boot without being able to match the
 * index already there. `users.email` ended up backed by eight identical unique
 * indexes. MySQL caps a table at 64, so this is not cosmetic: left alone, DDL
 * eventually fails outright on the tables every login path touches.
 *
 * Rules, all of them narrowing:
 *   • Only exact duplicates — same column list, same order, same uniqueness.
 *   • PRIMARY is never a candidate.
 *   • Every index named in schema.json is kept, however many duplicates of it
 *     there are. The JSON is the authority; this only removes what it does not
 *     declare.
 *   • If a group has no declared member, the first by name is kept. A group
 *     never loses its last index, so a foreign key can never be left without
 *     one.
 */

const { quoteIdentifier } = require('./schemaDdl');

/**
 * Groups indexes by what they actually cover and works out which copies are
 * redundant.
 *
 * @param {object} desired parsed schema.json
 * @param {object} live    output of schemaIntrospect.introspect()
 * @returns {Array<{table, columns, unique, keep: string[], drop: string[]}>}
 */
function findRedundantIndexes(desired, live) {
  const groups = [];

  for (const [tableName, liveTable] of Object.entries(live.tables)) {
    const declared = new Set(Object.keys((desired.tables[tableName] || {}).indexes || {}));
    const byShape = new Map();

    for (const [indexName, index] of Object.entries(liveTable.indexes)) {
      const shape = `${index.unique ? 'U' : 'K'}:${index.columns.join(',')}`;
      if (!byShape.has(shape)) byShape.set(shape, []);
      byShape.get(shape).push({ name: indexName, ...index });
    }

    for (const [, members] of byShape) {
      if (members.length < 2) continue;

      const names = members.map((m) => m.name).sort();
      const keep = names.filter((n) => declared.has(n));
      // No declared member: keep the first by name so the group keeps one.
      if (!keep.length) keep.push(names[0]);

      const drop = names.filter((n) => !keep.includes(n));
      if (!drop.length) continue;

      groups.push({
        table: tableName,
        columns: members[0].columns,
        unique: members[0].unique,
        total: members.length,
        keep,
        drop,
      });
    }
  }

  return groups.sort((a, b) => b.drop.length - a.drop.length);
}

/**
 * Turns the groups into one operation per index, in the shape `runOperations`
 * already understands, so cleanup reports progress through the same job row.
 *
 * One statement per index rather than one per table: if a single drop fails —
 * a lock, an index backing something unexpected — the rest still go, and the
 * job says exactly which one stopped.
 */
function buildCleanupOperations(groups) {
  const operations = [];

  for (const group of groups) {
    for (const indexName of group.drop) {
      operations.push({
        kind: 'dropRedundantIndex',
        table: group.table,
        risk: 'cleanup',
        description: `Drop redundant index ${group.table}.${indexName} — identical to `
          + `${group.keep.join(' / ')} on (${group.columns.join(', ')})`
          + `${group.unique ? ', unique' : ''}`,
        sql: `ALTER TABLE ${quoteIdentifier(group.table)} DROP INDEX ${quoteIdentifier(indexName)}`,
      });
    }
  }

  return operations;
}

module.exports = { findRedundantIndexes, buildCleanupOperations };
