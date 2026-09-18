# Handover — admin & coach panels, payouts, SMS

**Last session: 17–19 Sep 2026.** Read this before touching `adminui/**`,
`backend-api/src/utils/{commission,razorpayRoute,settleBooking,refundBooking,sms}.utils.js`,
or the webhook controller.

`CLAUDE.md` is still the law for how this repo works. This file is only *where we got to* — it
says nothing `CLAUDE.md` says, and where the two disagree, the code wins and this file is stale.

**Build log, written for a non-technical reader (what is done, waiting, unbuilt):**
https://claude.ai/artifact/ReTp3dcs1L2BBuEJ1haJUU

**System map from the previous session (flows, what exists, what doesn't) — still broadly
accurate, but predates everything below:**
https://claude.ai/code/artifact/c3351a7b-e778-4bbf-8d4c-d7a953dc6d51

The previous handover (ground owner panel, 11–12 Sep) is in this file's git history:
`git show 0b95826:.claude/HANDOVER.md`.

---

## 1. The things to know before anything else

**Every booking still auto-cancels five minutes after it is created**, on any environment
without Razorpay keys — which is all of them. Pay-at-ground is not exempt:
`utils/pricing.splitPayment` takes a 10% advance online, so `requiresPayment` is true for both
payment methods. Unchanged from the last session, and still the single highest-value thing
outstanding. To get a confirmed booking locally, use the owner's "collect cash" button.

**MSG91 reports success for a send made with an invalid key.** Verified against the live API:
an authkey of `totally_fake_key_12345` answers `{"type":"success","message":"<request id>"}`
with HTTP 200. Nothing in a send response can tell you the message will arrive. A wrong key in
production looks perfectly healthy in the logs while every OTP vanishes. `checkMsg91Health()`
runs at boot and shouts if the balance is 0, which catches both a bad key and an exhausted
account — that alarm is the only thing standing between you and a silent outage.

**Creating a Razorpay transfer is not the same as it landing.** `settleCapturedPayment` records
the transfer id and leaves `vendor_payout_status` as `pending` on purpose. Only the
`transfer.processed` webhook writes `transferred`. If you find yourself wanting to set that
status anywhere else, you are about to make the ledger lie.

**`admin.playsher.com` is pinned to a build from 19 April 2026.** Five months of merged work
has never reached it. `playsher-admin.vercel.app` is current. This is a Vercel domain
assignment, not a deploy failure — nothing in the repo can fix it.

---

## 2. What shipped (merged to `main`, merge commit `b237ecc`)

Thirteen commits, branch `admin-panel-redesign`, merged with `--no-ff`.

| Commit | What |
| --- | --- |
| `ea89f40` | Marketing site served at `/landing-demo` alongside the panel |
| `f77f70e` | Admin and coach rebuilt as app shells (`PanelShell`), navigation from one config |
| `d2b960c` | AppShell/Sidebar/Topbar deleted; palette switcher and unread badge moved, not lost |
| `a73e92c` | Shared primitives rebuilt — every page inherits the phone treatment |
| `9d4da70` | `ResponsiveDialog`; the admin booking dialog reads the fields the API actually sends |
| `db18835` | Razorpay Route payouts with commission |
| `92c6ab1` | Payout split shown to the owner; admin retry for a stuck payout |
| `98692ea` | Super admin sets the commission rate from the panel |
| `bd06c24` | Razorpay webhook; account activation tracking; refund reverses the owner's share |
| `f6f0c58` | Five missing screens |
| `dce1fb1` | MSG91 replaces Twilio for OTP |
| `30107e3` | The Flutter app stops swallowing OTP send failures |
| `3577ed4` | Refund action in the panel; owners told when their payout account is stuck |

### The bugs found on the way

1. **`/admin/bookings` and `/admin/payments` rendered blank white screens.** MUI X DataGrid v7
   changed `valueGetter` from `({ row })` to `(value, row)`; three columns still used the v6
   form, so every cell threw. Other pages had already been migrated — these three were
   stragglers. If you add a column, use the v7 signature.

2. **The admin booking dialog showed `—` for ground, start time, end time and phone.** It read
   `booking.ground`, `booking.slot_time` and `customer.phone`; the API nests the ground under
   `groundSport`, names the times `slot_time_from`/`slot_time_to`, and the number `mobile`.
   `groundNameOf` lived *inside* the page component while the dialog sat above it, so the dialog
   grew a second, wrong copy. It is hoisted to module scope now — **do not re-inline it.**

3. **`Booked On` was empty on every row.** Sequelize is `underscored: true` for columns but still
   names the timestamp attribute `createdAt`, so this one key serialises camelCase while every
   other is snake. `bookedOn()` in `pages/admin/Bookings.jsx` reads both.

4. **`grounds.contact_number` was declared in the model and in `schema.json` but had never been
   applied to the local database**, so every query including `Ground` threw. Found only because
   settlement joins through it. Applied via the schema panel's own engine. Worth checking on any
   environment you inherit.

### Decisions worth not re-litigating

- **Navigation is one config** (`adminui/src/config/navigation.jsx`), read by the rail, the
  bottom bar and the More screen. Hiding a page is `hidden: true` on its item — the route still
  resolves and a direct link still works. There is deliberately no second list.
- **`navSelectors.js` holds the pure reads with no icon imports**, so the rules that are silent
  when wrong have a runnable check. The `/` boundary case is the one to keep:
  `/admin/ground-owners` must not light the `/admin/grounds` tab.
- **The commission rate is frozen onto each payment at capture** (`platform_fee`). Changing the
  rate never restates what an owner already earned, and a retried transfer sends
  `vendor_payout_amount` **as recorded**, not a recomputed figure.
- **Refunds reverse the owner's share first, then refund the customer.** If the reversal fails,
  nothing is refunded. Refusing is recoverable; refunding money that cannot be clawed back is
  not. `force: true` is the deliberate override and is logged.
- **The commission fee floors to the paise**, so rounding can never favour the platform over the
  owner. `fee + owner === captured`, exactly, is asserted across the range.
- **OTP verification stays on our server.** MSG91's browser widget sends *and* verifies in a web
  page and hands the backend a token — that is what `nammacollection` does, and it cannot work
  for a Flutter client. Only the transport changed.
- **Coach sessions produce no ground-owner revenue**, because the data model has the customer
  paying the coach directly. No revenue share was invented. If owners should earn from coaching,
  that is a pricing decision and a schema change.
- **`OwnerShell` was left alone.** It predates `PanelShell`, carries a provider and a
  coach-request badge that do not generalise, and folding it in is a separate change.

### API surface added (all additive)

- `POST /webhooks/razorpay` — signature-authenticated, no bearer token
- `GET  /admin/settings/commission`, `PUT` the same (super admin only)
- `POST /admin/payments/:id/retry-payout`
- `POST /admin/payments/:id/refund` (super admin only)
- `GET  /ground-owner/reviews`
- `GET  /coach/earnings`
- `GET /ground-owner/settlements` — gains `commission_total`, `online_net`,
  `payout_account_status`, and `payout_state` can now be `account_*`
- `bookingIncludes` selects `user.email` — additive; the customer app ignores what it does not read

### Schema changes (via `database/schema.json`, per CLAUDE.md §6)

- `ground_owners.razorpay_linked_account_id`, `ground_owners.razorpay_account_status`
- `payments.vendor_payout_status` gains `failed` and `reversed`
- new table `platform_settings` (key/value, so the next tunable value needs no migration)
- plus `grounds.contact_number`, which was already declared and simply never applied

**All applied to the local database already.** A fresh environment applies them from the panel.

---

## 3. What is still pending

| # | Item | Blocked on |
| --- | --- | --- |
| 1 | **Razorpay keys, Route activation, per-owner KYC** | the user's account |
| 2 | **MSG91 key, DLT template ID, sender ID, DLT registration** | the user's account |
| 3 | **`RAZORPAY_WEBHOOK_SECRET`** + subscribing the six events | the Razorpay dashboard |
| 4 | **`admin.playsher.com` repointed** | Vercel domain settings |
| 5 | **`OTP_DEV_BYPASS=false`** before any public traffic | a deploy setting |
| 6 | Pay-at-ground earns ~1%, not 10% | a business decision — see below |
| 7 | Do owners earn from coach sessions? | a business decision |
| 8 | MSG91 delivery-report webhook | the only real proof a message landed |
| 9 | Push (FCM), coupons, Google Maps key | unbuilt, as before |

**On (6):** commission applies only to money that passes through Playsher. For pay-at-ground
that is the 10% advance, so a ₹1,200 booking earns ₹12. Online bookings give the full rate.
Raising the commission rate raises it for both. Changing the *advance* rate in
`utils/pricing.js` is the other lever.

### Never tested against the real thing

Every Razorpay-facing call — `accounts.create`, `products.requestProductConfiguration`,
`payments.transfer`, `transfers.reverse` — has only ever run without keys. The no-keys path is
proven; the live path is not. `accounts.create` carries the documented Route shape but has never
had a response.

### Smaller gaps

- `/admin/vendors` undercounts — reads `bookings.payment_id` instead of `Payment.booking_id`
- `database/seed.js` still dies partway; reviews, games and coaches never seed
- `backend-api` has a `lint` script but eslint is still not installed
- The coach panel's Grounds, Notifications and Profile screens were never checked at phone width
- Refunds have no partial-amount input in the UI — the endpoint takes one, the dialog does not

---

## 4. Running it locally

Unchanged from the last session, plus:

```
MariaDB   mysqld --defaults-file=C:\playsher-local-db\my.ini --console
API       cd backend-api && node server.js          → :3000, /api-docs
Panel     cd adminui && npm run dev                 → :5173
App       cd mobile_app && flutter run -d web-server --web-port=5000
```

**Do not use the XAMPP default datadir** (`C:\xampp\mysql\data`) — its InnoDB files are corrupt.

### Checks to run

```
node backend-api/src/utils/commission.test.js      # the money split
node backend-api/src/utils/payoutSafety.test.js    # webhook signature, refund reversal
node backend-api/src/utils/sms.test.js             # MSG91 failure modes
node adminui/src/config/navSelectors.test.js       # navigation rules
cd adminui && npm run lint && npm run build        # must stay clean
cd mobile_app && flutter analyze && flutter test   # 416 tests
```

These are plain `node` scripts on purpose — `backend-api` and `adminui` have no test runner, and
adding one was not this session's job. Each covers something silent when wrong.

### Local logins

| Role | Credentials |
| --- | --- |
| Admin (super) | `admin@playsher.com` / `123` — seeded this session |
| Admin | `sabarish@playsher.com` / `sabarish` |
| Ground owner | `ali@playsher.com` / `Owner@123` (2 grounds, bank details seeded) |
| Ground owner | `zara@playsher.com` / `Owner@123` (2 grounds) |
| Coach | `coach@playsher.com` / `123` — seeded this session, approved |
| Customers | `9876543210`, `9123456780` — OTP bypass on, any 6 digits |

**Test data seeded this session, local only:** two reviews and two coach sessions on Ali's
ground, and bank details for Ali. They exist so the Reviews and Earnings screens render
something; delete them whenever.

### Traps that cost time this session

- **Vite serves a stale transform after an out-of-band edit.** A file edited by a script rather
  than by the editor left the dev server serving the *old* module while the source on disk was
  correct — the page stayed blank through several fixes. `rm -rf node_modules/.vite` and
  restart. Suspect this before you suspect your change.
- **The API server must be restarted for a new route.** Obvious in hindsight; it cost a
  debugging round when a new endpoint answered 404 while the code was plainly there.
- **Rate limiting is per IP**, still 100 per 15 min by default, still raised to 1000 locally.
  The webhook path is now exempt — Razorpay delivers from a small pool of addresses.

---

## 5. Deployment — unchanged, and still hands-off

Vercel deploys through its own Git integration, configured off-repo. `main` → production.
There is no deploy workflow in the repository.

The user's standing instruction still holds: **do not touch the deployment pipeline, the CI
workflows, or the server-side setup**, and ask before any API change that could affect the
customer app. The one such change this session — adding `email` to `bookingIncludes` — was
asked for and approved.

---

## 6. Conventions this work followed

Beyond `CLAUDE.md` and `docs/admin-ui-guidelines.md`:

- **Admin and coach pages compose `components/ui/*`** — `PageHeader`, `DataTable`, `DrawerForm`,
  `ConfirmDialog`, `ResponsiveDialog`, `StatusChip`, `EmptyState`. All of them now carry their
  own phone behaviour, so a page gets it by composing rather than by handling breakpoints.
- **Modal surfaces rise from the bottom on a phone** and stay a right drawer or a centred dialog
  on a laptop. `DrawerForm` and `ResponsiveDialog` both do this; anything new should too.
- **Colour comes from `theme.palette`**, never a hex in a component. The brand blue `#0061C2` is
  the theme default and also the first palette swatch. The one deliberate exception is
  `pages/Login.jsx`, which is pre-auth: the palette picker is a signed-in preference and must not
  repaint the front door.
- **Surfaces are defined by a hairline border, not a shadow.** The shadow ramp is flat for the
  first three levels; only menus and dialogs float.
- **Money paths leave a runnable check.** Four exist. Add to them rather than starting a fifth
  pattern.
- The comments in these files explain *why*, usually by naming the bug that made the rule. Two of
  them record things verified against a live third-party API that contradict the obvious
  assumption — keep those especially.
