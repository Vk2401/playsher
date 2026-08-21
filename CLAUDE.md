# Playsher — Agent Instructions

**Read this before touching any file in this tree.**

> Note on location: this project happens to live under `/opt/homebrew/var/www/`. The
> Homebrew instructions at `/opt/homebrew/AGENTS.md` (Ruby, Sorbet, `./bin/brew lgtm`)
> **do not apply here** and must be ignored for any work inside `play/`.

@docs/mobile-ui-guidelines.md
@docs/admin-ui-guidelines.md

---

## 1. What this is

Playsher is a sports-ground booking platform for the Indian market (multi-city).
Three codebases in this directory, one product:

| Directory      | Product                                   | Stack                                        |
| -------------- | ----------------------------------------- | -------------------------------------------- |
| `backend-api/` | REST API (`app.playsher.com`)             | Node 18+ · Express 4 · Sequelize 6 · MariaDB  |
| `adminui/`     | Admin **and** Ground Owner panels (one SPA at `admin.playsher.com`) | React 18 · Vite 5 · MUI 6 · TanStack Query 5 |
| `mobile_app/`  | Customer app (Android + iOS)              | Flutter 3.22 · Dart 3.4 · Riverpod · GoRouter |

Three user roles exist end-to-end and the token payload role string is the contract:
`user` (customer, OTP login) · `ground_owner` (email+password) · `admin` (email+password).

`admins.role` (`super_admin` | `admin`) is a **tier inside** the admin role, not a fourth role —
every admin still authenticates as `admin` in the JWT. It gates only `/admin/admins*`, is read
from the row on each request rather than from the token (so a demotion takes effect at once),
and while no `super_admin` exists the oldest active admin inherits the tier so the panel is
never shipped locked. See `src/middleware/superAdmin.js`.

Full product context: `Playsher Technical Specification.docx` in this directory.
It is the **spec**, not the source of truth — when it disagrees with the code, the code wins;
say so rather than "fixing" working code to match the doc.

## 2. The one rule that shapes everything

**The API response envelope is the contract between all three apps.** Every endpoint answers:

```jsonc
{ "success": true,  "message": "Grounds retrieved.", "data": …, "pagination": {…} }  // optional data/pagination
{ "success": false, "message": "Validation failed.", "errors": [{ "field", "message" }] }
```

Produced *only* by `src/utils/response.js` (`success()` / `error()`). Both clients unwrap
`data` (Flutter: `raw['data'] ?? …`; React: `res.data?.data`). Changing an envelope, a field
name, or a `data` shape is a **three-codebase change** — grep the other two before shipping it,
and update the Swagger JSDoc on the route.

Field naming is `snake_case` everywhere on the wire (Sequelize `underscored: true`).
Do not camelCase a payload key. Dart models map to camelCase *inside* the model class only.

## 3. Layering — per codebase

**Backend** — request flows one way, never skip a layer:
`routes/*.routes.js` (path + swagger + auth + validator) → `middleware/validate` →
`controllers/*.controller.js` (orchestration + response) → `models/` (Sequelize) ,
with `utils/` for pure helpers. No SQL strings, no `res.json()` outside `utils/response.js`,
no business logic in routes, no `req`/`res` inside `utils/`.

**Admin UI** — `api/*.js` (axios endpoint map) → TanStack Query hooks *in the page* →
`pages/**` → `components/ui/*` primitives. A page never calls `axios` directly and never
builds a URL string; add the method to the matching `src/api/<domain>.js` object.

**Flutter** — `core/api_client.dart` (the single Dio client + every endpoint) →
`models/` (`fromJson` factories) → `providers/` (Riverpod) → `screens/` → `widgets/`.
A screen never calls `ApiClient` directly; it watches a provider.

Cross-cutting: **one HTTP path per app.** One axios instance (`src/api/client.js`), one Dio
instance (`ApiClient.instance`). Both carry the `Authorization` header and the 401 →
refresh-token → retry → logout flow. Never construct a second client or set auth headers by hand.

## 4. Working in this repo

- **Only `mobile_app/` has tests** — `flutter test` runs ~120 of them (models, layout/overflow
  guards, navigation). Run it for any Flutter change. `backend-api/` and `adminui/` have no test
  suite at all; there, verify with the checks below and say plainly what you did and did not verify.
- Backend: `npm run dev` (nodemon, port 3000), `npm run lint`. Swagger at `/api-docs` — a new
  endpoint without a `@swagger` JSDoc block on its route is incomplete.
- Admin UI: `npm run dev` (5173, proxies `/api` → localhost:3000), `npm run build`,
  `npm run lint` (`--max-warnings 0` — it must stay clean).
- Flutter: `flutter analyze` must be clean; `flutter run`. `flutter_lints` is on.
- Secrets live in `.env` (`backend-api/.env`, `adminui/.env`) and are **not** committed.
  Never hardcode a host, key, or credential — `AppConstants.baseUrl` and
  `VITE_API_BASE_URL` are the only places a backend URL may appear.
  `AppConstants.razorpayKeyId` currently holds a **test** key; it must move to a build-time
  define before release, and never gain a live key in source.
- **Changing a table or column means editing `backend-api/database/schema.json` and nothing
  else** — see §6. Don't hand-write SQL and don't add a migration file.
- Keep diffs minimal and match the surrounding style: the backend uses aligned object literals
  and `// ── Section ───` comment rules; follow them.

## 5. Known gaps — do not "discover" these as new

State them plainly if relevant; don't silently paper over them.

- OTP now lives in the `otps` table (`otp.controller.js`), so it survives restarts and works
  across multiple processes. `OTP_DEV_BYPASS=true` makes any 6-digit code valid for a correctly
  formatted Indian mobile — a demo-only setting that must be `false` in production.
- Twilio, Razorpay live keys, Google Maps key and DLT registration are all **pending** —
  OTP prints to the server console until Twilio is configured.
- Several Flutter `ApiClient` methods are **stubs returning empty data**: notifications,
  coupons, rewards, cities, price filters, dashboard. Screens built on them show empty states,
  not bugs. Implement the endpoint before "fixing" the screen.
- Push notifications (FCM) are Phase 2 and not wired anywhere.
- `sequelize.sync({ alter: false })` runs outside production only. It must never become
  `alter: true` — past runs are why `users`, `admins` and `ground_owners` each carry three or
  four duplicate unique indexes on `email`/`mobile`, and why some columns are nullable where
  their migration said `NOT NULL`. Schema changes go through `database/schema.json` (§6).
- The `database/migrations/*.sql` files are **history, not the mechanism**. They record how the
  schema got here and are all applied; new changes go in the JSON instead. Don't add a file
  there.

## 6. The database schema lives in one JSON file

**`backend-api/database/schema.json` is the source of truth for every table and column.**
To change the schema you edit that file — nothing else. No `ALTER TABLE` typed by hand, no new
file in `database/migrations/`, and never `sync({ alter: true })`.

The flow, end to end:

1. **Edit `database/schema.json`.** Add the table, column, index or foreign key you want.
2. **Admin panel → Database Schema** (`/admin/database-schema`). It shows the difference
   between the JSON and the live database, with the exact SQL for every change.
3. **Press "Apply schema"**, read the confirmation dialog, confirm. Progress streams back
   step by step.

Every column must declare a real type **and its size** — `varchar` needs `length`, `decimal`
needs `precision`/`scale`, `enum` needs `values`. A column with no size is rejected when the
file is loaded, because an unsized type is how a `VARCHAR(255)` silently becomes a
`TEXT` nobody can index.

```jsonc
"grounds": {
  "columns": {
    "id":       { "type": "int", "length": 10, "unsigned": true, "nullable": false, "autoIncrement": true },
    "name":     { "type": "varchar", "length": 255, "nullable": false },
    "city":     { "type": "varchar", "length": 100, "nullable": true },
    "has_roof": { "type": "tinyint", "length": 1, "nullable": false, "default": 0 },
    "price":    { "type": "decimal", "precision": 10, "scale": 2, "nullable": false, "default": 0 },
    "status":   { "type": "enum", "values": ["draft", "live"], "nullable": false, "default": "draft" }
  },
  "primaryKey": ["id"],
  "indexes":     { "idx_grounds_city": { "columns": ["city"], "unique": false } },
  "foreignKeys": { "grounds_ibfk_1": { "columns": ["owner_id"],
                                       "references": { "table": "ground_owners", "columns": ["id"] },
                                       "onDelete": "CASCADE", "onUpdate": "CASCADE" } }
}
```

### What the engine will and will not do

**It never destroys data.** There is no code path that emits `DROP TABLE`, `DROP COLUMN` or
`TRUNCATE` — not behind a flag, not with a confirmation. A table or column that exists in the
database but not in the JSON is reported as an *extra* and left alone; removing something is a
deliberate manual act, never a side effect of editing the file.

Every change is classified, and the classification is what the admin confirms:

| Risk | Meaning | Runs |
| --- | --- | --- |
| `safe` | Cannot lose data or fail on existing rows: create table, add column, add index, add FK, widen a column, relax `NOT NULL`, change a default, append enum values. | by default |
| `risky` | Succeeds but touches existing values: narrowing a column, removing enum values, tightening `NULL` → `NOT NULL` (NULLs are backfilled with the column's default first). | only when the admin ticks "Include these as well" |
| `blocked` | Cannot be done safely at all — e.g. a new `NOT NULL` column with no `default`, or an index whose definition changed. Reported with the reason, never executed. | never |

**A new `NOT NULL` column must have a `default`.** That is the rule that keeps existing rows
intact: the default is what they get. Without one the change is `blocked` rather than silently
letting MariaDB invent a zero or an empty string.

Adding a table or column is safe to re-run — `CREATE TABLE IF NOT EXISTS`, and the plan is
rebuilt from the live database on every request, so a sync that stopped halfway just resumes.

### The pieces

| File | Role |
| --- | --- |
| `database/schema.json` | the declared schema — **edit this** |
| `src/utils/schemaIntrospect.js` | reads the live database into the same shape |
| `src/utils/schemaDiff.js` | desired vs live → classified operations. The safety rules live here. |
| `src/utils/schemaDdl.js` | the only file that writes SQL syntax |
| `src/utils/schemaSync.js` | runs the plan, records progress in `schema_sync_jobs` |
| `src/controllers/schema.controller.js` + `src/routes/schema.routes.js` | `GET/POST /api/v1/admin/schema*`, admin-only |
| `adminui/src/pages/admin/DatabaseSchema.jsx` | the panel: diff, confirm, progress |
| `database/generate-schema-json.js` | one-way capture — regenerates the JSON *from* a database |

**Fresh database / new environment.** Point `.env` at the empty database and apply from the
panel: every table is a `createTable`, so a first run builds the whole schema. That is the
intended path for a new deployment, and the reason initial setup and incremental change are
the same button.

Two things to keep in mind:

- **The Sequelize models in `src/models/` are a separate declaration and are not generated from
  the JSON.** Adding a column to the JSON does not make it readable through a model — add it to
  the model file too, or the API will not select it. Keep the two in step; a mismatch here is
  how a column ends up existing but invisible.
- `schema_sync_jobs` is created by the engine itself before the first run, so progress survives
  the API running as several processes.

## 7. Skills

Load the matching skill before non-trivial work — each carries the concrete file-level patterns:

| Skill                 | Use when                                                     |
| --------------------- | ------------------------------------------------------------ |
| `playsher-backend`    | any change under `backend-api/` — endpoints, models, auth     |
| `playsher-admin-panel`| any change under `adminui/` — pages, tables, forms            |
| `playsher-flutter`    | Flutter architecture — providers, models, routing, API calls  |
| `playsher-mobile-ui`  | any Flutter **UI** work — screens, widgets, theming, motion   |
