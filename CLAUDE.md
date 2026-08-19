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

- **No test suites exist** in any of the three projects. Do not claim tests pass. Verify with
  the checks below and say plainly what you did and did not verify.
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
- `sequelize.sync({ alter: false })` runs outside production only; schema changes go through
  SQL migration files in `backend-api/database/`, never through `sync({ alter: true })`.

## 6. Skills

Load the matching skill before non-trivial work — each carries the concrete file-level patterns:

| Skill                 | Use when                                                     |
| --------------------- | ------------------------------------------------------------ |
| `playsher-backend`    | any change under `backend-api/` — endpoints, models, auth     |
| `playsher-admin-panel`| any change under `adminui/` — pages, tables, forms            |
| `playsher-flutter`    | Flutter architecture — providers, models, routing, API calls  |
| `playsher-mobile-ui`  | any Flutter **UI** work — screens, widgets, theming, motion   |
