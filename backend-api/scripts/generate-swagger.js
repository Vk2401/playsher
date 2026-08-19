/**
 * Writes the OpenAPI spec to src/config/swagger.generated.json.
 *
 * swagger-jsdoc scans route files from disk at runtime, which fails on hosts
 * that bundle the app into a single file. Running this at build time produces a
 * static spec that survives bundling. Wired to `npm run build`.
 */
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, '..', 'src', 'config', 'swagger.generated.json');

// Remove any stale artefact first so the fallback inside swagger.js cannot
// feed this script its own previous output.
fs.rmSync(OUT, { force: true });

const spec = require('../src/config/swagger');
const count = Object.keys(spec.paths || {}).length;

if (count === 0) {
  console.error('generate-swagger: no endpoints found — is src/routes/*.js present?');
  process.exit(1);
}

fs.writeFileSync(OUT, JSON.stringify(spec, null, 2));
console.log(`generate-swagger: wrote ${count} endpoints to ${path.relative(process.cwd(), OUT)}`);
