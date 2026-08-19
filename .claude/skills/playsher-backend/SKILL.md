---
name: playsher-backend
description: Architecture and code patterns for the Playsher Node/Express/Sequelize API in `backend-api/`. Load before adding or changing an endpoint, controller, model, validator, migration, auth rule, or Swagger doc — it carries the exact file layout, the response envelope, the role model, and the transaction/slot-booking rules.
---

# Playsher backend — how this API is built

Node 18+ · Express 4 · Sequelize 6 (mysql2) · MariaDB 10.6 · JWT · Swagger. Entry:
`server.js` → `src/app.js` → `src/routes/index.js`. Everything mounts under `/api/v1`.

## The layers, and what may live in each

```
src/routes/<domain>.routes.js   path + @swagger block + auth middleware + validator chain + ctrl ref
src/middleware/                 auth (verifyToken, requireRole) · validate · upload · error
src/controllers/<d>.controller.js  orchestration, Sequelize queries, returns via success()/error()
src/models/<Model>.js           sequelize.define factory — columns only, no logic
src/models/index.js             instantiates every model + ALL associations, exports them
src/validators/<d>.validator.js express-validator chains, exported by action name
src/utils/                      pure helpers — no req/res, no HTTP status knowledge
src/config/                     database · jwt · swagger
```

Hard rules:
- **`res.json()` appears in exactly three files**: `utils/response.js`, `middleware/error.js`,
  and the two health routes in `app.js`. Controllers return `success(...)` / `error(...)`.
- **No raw SQL.** Sequelize only — it's the SQL-injection boundary.
- **No business logic in a route file.** Routes wire; controllers decide.
- **No `req`/`res` in `utils/`.**

## The response envelope — the cross-app contract

```js
success(res, 'Grounds retrieved.', data, 200, paginationMeta(count, page, limit));
error(res, 'Ground not found.', 404);
```

→ `{ success, message, data?, pagination? }` / `{ success, message, errors? }`.

Messages are short, sentence-case, and end with a period. The Flutter app and the admin panel
both unwrap `data` — changing a key is a three-codebase change (see `CLAUDE.md` §2).

Validation failures are produced by `middleware/validate` as **422** with
`errors: [{ field, message }]`. Never hand-roll that shape.

## Adding an endpoint — the whole checklist

1. **Validator** in `src/validators/<domain>.validator.js`, exported by action name
   (`createGround`, `updateGround`). Validate `param` ids with `isInt({ min: 1 })`.
2. **Controller action** in `src/controllers/<domain>.controller.js` as
   `exports.<action> = async (req, res) => { try { … } catch (err) { return error(res, err.message, 500); } }`.
   Prefix it with a `// VERB /path` comment — that's the house convention.
3. **Route** in `src/routes/<domain>.routes.js`, in this exact middleware order:
   `verifyToken, requireRole(...), <validatorChain>, validate, ctrl.<action>`.
4. **Swagger JSDoc** `@swagger` block immediately above the route. An endpoint without one is
   incomplete — `/api-docs` is the deliverable the client integrates against.
5. Mount the router in `src/routes/index.js` if the domain is new.

## Auth & roles

- `middleware/auth.js` is the only place a token is verified. It sets `req.user = { id, role }`.
- Three role strings, and they are the contract with both clients: **`user`** (customer, OTP),
  **`ground_owner`**, **`admin`**. `requireRole('ground_owner', 'admin')` for shared endpoints.
- **Role check ≠ ownership check.** `requireRole` proves *what kind* of actor; the controller
  must still prove *this* actor owns the row:
  ```js
  if (req.user.role === 'ground_owner' && ground.owner_id !== req.user.id) {
    return error(res, 'Forbidden.', 403);
  }
  ```
  Every owner-scoped read, update and delete needs this. A list endpoint scopes by joining on
  `Ground.owner_id` (see `booking.controller.js` `list`), never by trusting a query param.
- Access tokens are short-lived (15m), refresh tokens live in the `refresh_tokens` table.
  `utils/jwt.utils.js` (HS256) is the only signer/verifier.
- Auth endpoints carry a **tighter rate limit** than the global one — keep `AUTH_RATE_LIMIT_MAX`
  applied to any new OTP or login route, or you've opened an OTP-abuse hole.

## Models & associations

- One file per model, a factory `module.exports = (sequelize) => sequelize.define(...)`,
  columns aligned in a block, `{ tableName: '…', underscored: true }`.
- **Every association lives in `src/models/index.js`**, never in the model file — that file is
  the single readable map of the schema. Always name the alias (`as: 'owner'`, `as: 'images'`)
  and use that alias in `include`.
- Soft deletes are a manual `deleted_at` column (not Sequelize `paranoid`), so **every** query
  on a soft-deletable model must carry `deleted_at: null` in its `where`. Missing it is how
  deleted grounds reappear.
- Booleans `is_approved` / `is_active` gate public visibility: the public list filters
  `{ is_approved: true, is_active: true, deleted_at: null }`.
- Schema changes are SQL files in `database/`, applied deliberately. `sequelize.sync` runs with
  `alter: false` and is skipped in production — never switch it to `alter: true`.

## Pagination & geo

`getPagination(req.query)` → `{ page, limit, offset }` (limit capped at 100, default 20), and
`paginationMeta(count, page, limit)` for the response. Use `findAndCountAll` with
`distinct: true` whenever the query has a `hasMany` include, or `count` is inflated by the join.

Nearby search is `haversineKm` filtering **in JS after the query** (`ground.controller.list`).
That's a known scale limit — it filters only the current page. Don't quietly extend the pattern
to a new endpoint without saying so; a bounding-box `where` on lat/lng is the fix.

## Booking & slots — the part that must not race

`booking.controller.create` is the reference for any money- or inventory-touching write:

- Open `const t = await sequelize.transaction()` **first**; every query inside passes
  `{ transaction: t }`; **every** early return does `await t.rollback()` before responding;
  `await t.commit()` only on the happy path; the `catch` rolls back.
- Slots are generated lazily: `ensureSlotsForDate(groundSportId, date, t)` creates 30-minute
  rows from the `ScheduleTemplate` for that `day_of_week`, refuses past dates, and never
  regenerates existing (possibly booked) slots.
- Availability is re-checked **inside** the transaction (`is_available: true` in the `where`,
  then `slots.length !== slot_ids.length` → reject). Never trust an availability check the
  client made earlier.
- `min_slots` / `max_slots` on the `GroundSport` bound the request; price is
  `price_per_half_hour × slot count`, computed server-side. **Never take an amount from the
  client.**
- Booking status: `online` → `pending` + `requires_payment: true`; otherwise `confirmed`.
  Reference format `YYYYMMDD-HHmm-HHmm-<id>`.
- Cancelling must release the slots (`is_available: true`) in the same transaction as the
  status change.

## Payments

Razorpay order creation, signature verification and webhooks live in `payment.controller.js`.
Verify the signature on **every** callback and webhook before mutating a booking — an unverified
callback is a free-booking exploit. Keys come from `.env`; never from source.

## Uploads

`middleware/upload.js` builds per-subdirectory multer storage (`uploads/sports`, `/amenities`,
`/coaches`, `/grounds`) with a 5 MB limit and an image-only filter. Reuse an existing exported
uploader; add a new one there rather than configuring multer in a route. Files are served
statically from `/uploads`.

## Checklist before calling backend work done

- `npm run lint` clean; server boots (`npm run dev`) and `/api-docs` renders the new route.
- Envelope unchanged, or both clients updated.
- Ownership check present on every owner-scoped row access.
- `deleted_at: null` on every soft-deletable query.
- Transactions roll back on every early return.
- No secret, host, or key added to source.
