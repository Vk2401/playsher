# Handover — ground owner panel

**Last session: 11–12 Sep 2026.** Read this before starting work on `adminui/src/pages/owner/**`,
`adminui/src/components/owner/**`, or `backend-api/src/controllers/ownerPanel.controller.js`.

`CLAUDE.md` is still the law for how this repo works. This file is only *where we got to* — it
says nothing `CLAUDE.md` says, and where the two disagree, the code wins and this file is stale.

**System map (flows, what exists, what doesn't):**
https://claude.ai/code/artifact/c3351a7b-e778-4bbf-8d4c-d7a953dc6d51

---

## 1. The thing to know before anything else

**Every booking auto-cancels five minutes after it is created**, on any environment without
Razorpay keys — which is currently all of them, including production.

Pay-at-ground is not exempt: `utils/pricing.splitPayment` takes a **10% advance online**, so
`requiresPayment` is true for both payment methods. The booking is created `pending` holding its
slots, `payment.controller` cannot build a Razorpay client without `RAZORPAY_KEY_ID` /
`RAZORPAY_KEY_SECRET`, the payment never lands, and `releaseExpiredHolds` sweeps the booking with
`cancellation_reason: "Payment not completed in time"`.

This was observed live, not inferred — two seeded bookings died this way mid-session.

**Consequences while the keys are missing:** you cannot test any journey that depends on a
confirmed booking (open games, reviews, owner notifications on create) through the normal path.
To get a confirmed booking locally, either record a payment directly
(`POST /payments` then mark it success) or use the owner's "collect cash" button, which confirms.

The keys are the single highest-value thing outstanding. The user said they will add them later.

---

## 2. What shipped (merged to `main`, commit `efd5a7e`)

Seven commits, branch `murali`, merged with `--no-ff`. **No schema change in any of them.**

| Commit | What |
| --- | --- |
| `b43be33` | Owner panel rebuilt as an app: Today · Bookings · My Ground · More |
| `f28684a` | Owner cancel frees slots + notifies customer; "collect cash at ground" |
| `62a5139` | Owner is notified when a customer books or cancels |
| `f52385d` | `GET /ground-owner/settlements` + Earnings screen |
| `0b61e32` | Header redesign across every owner screen |
| `b6afc90` | Today's schedule hides cancellations; booking rows grouped into one card |
| `9fc0f41` | Spacing on the next-booking hero and stat tiles |

### The three real bugs that were fixed

1. **Owner cancel left slots blocked for ever.** `ownerPanel.cancelBooking` only flipped
   `status`; the customer's own cancel released the slots properly. Two implementations, one of
   them wrong. Now both call `cancelBookingAndReleaseSlots` in `utils/slotHolds.js`.
   **Route any new cancel path through that function** — the second copy is what drifted last time.

2. **Nobody was told anything.** Neither cancel path notified. Now: owner cancel → customer is
   told (inside the same transaction, so it rolls back with the cancellation); customer books or
   cancels → owner is told, via `notifyGroundOwnerOfBooking` in `utils/notify.js`.

3. **No way to record cash taken at the gate.** `POST /ground-owner/bookings/:id/collect` writes
   a `payment_mode: offline, payment_status: success` row, clears `balance_due`, confirms the
   booking. Answers 409 on a repeat rather than writing a second row.

### Decisions worth not re-litigating

- **`notifyGroundOwnerOfBooking` is only called once a booking is confirmed**, never on create
  while money is owed. A pending booking usually dies in five minutes (§1); notifying on create
  would fill the inbox with bookings that never happened.
- **Settlements reads `Payment.booking_id`, not `bookings.payment_id`.** A pay-at-ground booking
  has *two* payments (advance online + balance at the gate) and one column can only point at one.
  The admin's `/admin/vendors` still reads it the other way and therefore undercounts.
- **`payout_state` is derived at read time, not stored.** `vendor_payout_status` is admin-written
  and nothing sets it automatically, so it reads "pending" for ever. Whether bank details exist is
  checkable, so `no_bank_details` is computed. The stored column stays the admin's own record —
  don't start writing to it from the owner side.
- **Cash reports as `collected_at_ground`, not "pending"** — the owner already holds it.

### API surface added (all additive, nothing renamed or removed)

- `POST /ground-owner/bookings/:id/collect`
- `GET  /ground-owner/settlements`
- `GET  /ground-owner/bookings` — optional `date`, `date_from`, `date_to`, `status`, `ground_id`, `search`
- `POST /auth/ground-owner/login` — response gains `status` and `created_at` (adminui is the only
  caller; the Flutter app has no ground-owner login)

**One shared path was touched:** `booking.controller.cancel`, which the customer app calls. It was
refactored to use the shared helper. Same response, regression-tested. If something misbehaves in
the app around cancelling, look there first.

---

## 3. What is still pending

Ordered by what unblocks the most.

| # | Item | Blocked on |
| --- | --- | --- |
| 1 | **Razorpay keys** | the user's account — see §1 |
| 2 | **Twilio + DLT** | OTP only prints to the server console, so no real user can sign in |
| 3 | **Refunds** | needs the live key to test. `payment_status: 'refunded'` exists; nothing sets it |
| 4 | **Payout automation** | a business decision: *when* does payout happen? On completion? Weekly? |
| 5 | **Push (FCM)** | phase 2, touches both codebases. The bell only rings when the panel is open |
| 6 | **Coupons / rewards** | Flutter `ApiClient` returns `{'data': []}` by design; no server side at all |
| 7 | **Google Maps key** | pending |

### Smaller gaps noticed but not acted on

- No `/owner/bookings/:id` route, so booking notifications land on the list, not the booking.
- Coach sessions are pay-at-venue and write no `payments` row, so they do not appear in Earnings.
- Owners cannot see reviews of their own grounds (customers write them, admins moderate them).
- `database/seed.js` fails partway — reviews/games/coaches never seed. Sports, amenities, owners,
  grounds, users do.
- `backend-api` has `npm run lint` in package.json but **eslint is not installed**, so it cannot run.

---

## 4. Running it locally

The `.env` files are gitignored and already set up on the user's machine.

```
MariaDB   C:\playsher-local-db        started from the XAMPP binaries, own datadir
          mysqld --defaults-file=C:\playsher-local-db\my.ini --console
API       cd backend-api && node server.js          → :3000, /api-docs
Panel     cd adminui && npm run dev                 → :5173
App       cd mobile_app && flutter run -d web-server --web-port=5000
```

**Do not use the XAMPP default datadir** (`C:\xampp\mysql\data`) — its InnoDB files are corrupt
(`log sequence number is in the future`). That is why a separate datadir exists. Leave the user's
own data alone.

Flutter SDK 3.41.7 (the CI-pinned version) is at `C:\src\flutter`.
`flutter analyze` is clean and all **337 tests pass**.

### Local logins

| Role | Credentials |
| --- | --- |
| Ground owner | `ali@playsher.com` / `Owner@123` (2 grounds) |
| Ground owner | `zara@playsher.com` / `Owner@123` (2 grounds) |
| Admin | `sabarish@playsher.com` / `sabarish` |
| Customers | `9876543210` (Karthik), `9123456780` (Priya) — OTP bypass on, any 6 digits |

### Two traps that cost time last session

- **Rate limiting is per IP.** `RATE_LIMIT_MAX` is 100 per 15 min by default. Testing exhausts it
  and the panel then renders empty states that look exactly like bugs — the tell is HTTP 429. It is
  raised to 1000 in the local `.env`.
- **The Flutter app points at the deployed API**, not localhost. `mobile_app/lib/core/constants.dart:7`
  hardcodes `https://playsher-api.vercel.app/api/v1` with no dart-define. Change it to test against
  a local backend; CORS already allows `:5000`.

---

## 5. Deployment — be careful here

- `.github/workflows/android-apk.yml` runs on **push to any branch** (`branches: ['**']`).
- `.github/workflows/ios-ipa.yml` runs **only** on a `v*` tag or manual dispatch. A branch push
  never touches TestFlight.
- **There is no deploy workflow in the repo.** Vercel deploys through its own Git integration,
  configured on vercel.com and not visible from here. Standard behaviour is `main` → production,
  any other branch → preview. Assume a push to `main` deploys production.

The user's standing instruction: **do not touch the deployment pipeline, the CI workflows, or the
server-side setup.** Work on the ground owner side only, and ask before any API change that could
affect the customer app.

---

## 6. Conventions this work followed

Beyond `CLAUDE.md` and `docs/admin-ui-guidelines.md`:

- **Owner screens compose `components/owner/OwnerBits.jsx`** — `Card`, `ScreenHeader`, `ListRow`,
  `InfoRow`, `Banner`, `Pill`, `EmptyNote`, `FilterChips`, `SectionTitle`. Don't rebuild these.
- **Lists are one `Card` with hairline-divided rows**, not a stack of bordered cards. The
  `last` prop drops the final divider. Bookings, payments and the earnings summary all do this.
- **Headers are two lines maximum.** `GroundSwitcher` for the tab screens, `ScreenHeader` for the
  pushed ones. Titles are `noWrap` — a long ground name used to wrap an h5 onto three lines and
  strand the switcher chevron beside the second one.
- Money uses `rupee()` from `ownerFormat.js` and `fontVariantNumeric: 'tabular-nums'` wherever
  figures line up in a column.
- The comments in these files explain *why*, usually by naming the bug that made the rule. Keep
  that when editing — several of them mark decisions that look arbitrary otherwise.
