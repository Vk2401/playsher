# Feature inventory — what we started with, what is still missing

Companion to the change summary. Two questions answered:
**1.** What was actually in the repository at the first commit (17 Aug 2026)?
**2.** What is still incomplete today (21 Aug 2026)?

---

## Part 1 — What existed at the first commit

The first commit was a large scaffold: **375 files, ~131,000 lines**, with all
three applications structurally in place. Almost every screen existed and
rendered. What was missing was the **wiring** — the connection between a screen
and the real data or the real action behind it.

Read the status column carefully; "the screen existed" and "the feature worked"
are two different things.

**✔ worked · ⚠ present but faulty · ✕ cosmetic only — the button did nothing**

### Server — 18 groups of endpoints

| Area | Status at first commit |
| --- | --- |
| Login: OTP for customers, password for owners/admins | ✔ (OTP held in memory — lost on every restart) |
| Grounds: list, detail, create, update, images, amenities | ⚠ owners could approve their own venue and edit others' |
| Sports and per-ground sports | ⚠ any owner could reprice any owner's ground |
| Slots: list, create, update, delete, open/close | ⚠ no ownership check at all on any write |
| Weekly schedule templates | ✔ |
| Bookings: create, list, detail, cancel | ⚠ slots held forever; cancel could half-fail |
| Payments + Razorpay order creation | ⚠ crashed the whole server if keys were absent |
| Games: create, join, leave, invite, respond | ✔ endpoints (the app never called join) |
| Reviews | ⚠ the eligibility check could be skipped entirely |
| Coaches: list, detail, admin CRUD | ✔ browse only — no way to book one |
| Favourites, amenities, sports catalogue | ✔ |
| Admin panel endpoints: list, approve, toggle, delete | ⚠ **no edit or update on anything** |
| Owner panel endpoints | ✔ |
| Vendor settlement figures | ✔ read-only reporting |

**Not present at all:** admin account management, password reset or change,
app-version control, the database schema tool, persistent OTP storage.

### Admin & owner panel — 21 pages

| Admin (14) | Owner (7) |
| --- | --- |
| Dashboard, Grounds, Ground detail, Ground owners, Users, Bookings, Payments, Settlements, Games, Reviews, Sports, Amenities, Coaches, Profile | Dashboard, Grounds, Ground detail, Bookings, Games, Bank details, Profile |

Shared building blocks were already there and are still the foundation today:
page headers, data tables, drawer forms, confirm dialogs, status chips, stat
cards, empty states.

| Known state | |
| --- | --- |
| ⚠ | **Nothing could be edited.** Approve, toggle and delete existed; update did not. |
| ⚠ | The admin bookings list rendered a dash in every cell. |
| ⚠ | Prices were shown in **Pakistani rupees**. |
| ✕ | Owners had **no slot screen** — the endpoints existed, no page used them. |
| ✕ | No password reset or change, anywhere, for anyone. |
| ⚠ | `npm run lint` could not run — its config file was never committed. |

### Customer app — 22 screens

| | |
| --- | --- |
| **Entry** | Splash, Onboarding, Phone, OTP, Register, Location |
| **Browse** | Home, Explore, Venue filters, Ground detail, Saved turfs |
| **Book** | Booking flow, Booking confirm, Bookings list, Booking detail |
| **Social** | Games, Game detail, Host a game |
| **Coaching** | Coaching list, Coach detail |
| **Account** | Profile, Settings, Notifications |

| Known state | |
| --- | --- |
| ⚠ | The three login screens were **white text on a white background**. |
| ⚠ | Booking: retry created a second booking; checkout quoted ₹0; past slots were on sale. |
| ⚠ | Bookings, games and the confirmation screen read fields the server never sent — blank dates, ₹0, dashes. |
| ⚠ | The ground page hid its own name under the photo; the gallery could not be swiped; booking was unreachable on arrival. |
| ✕ | **Host a Game** said "Game published!" and created nothing. |
| ✕ | **Join Match** and **Book Coach** showed a success message and did nothing. |
| ✕ | Apply Filters discarded every choice. |
| ✕ | The favourite heart on the ground page was wired to nothing. |
| ✕ | No profile editing — the pencil icon was decorative. |
| ✕ | Notifications showed four invented entries and a permanent unread badge. |
| ⚠ | Grounds with no photo fell back to a random stock image from the internet. |
| — | One test file, and it was failing. |

---

## Part 2 — What is incomplete today

Grouped by what it would take to finish. Nothing here is a regression; these
are areas that were never completed.

### A. Built on one side only — the button exists, the action does not

These are the highest-value gaps, because the work is half done already.

| Feature | What is there | What is missing |
| --- | --- | --- |
| **Join a match** | The full endpoint set exists on the server: join, leave, invite, respond to invite. | The app never calls any of them. "Join Match" shows a success message and joins nothing. Same class of defect as the old Host a Game. |
| **Book a coach** | Coaches can be created, approved and browsed. | There is **no coach-booking endpoint at all**. "Book Coach" shows "Booking request sent!" and sends nothing. Coaching is a directory, not a service. |
| **Refunds** | A payment can be marked "refunded" in the panel. | **No money moves.** Nothing calls Razorpay's refund. Cancelling a paid booking records the intent and stops there. |
| **Owner payouts** | Payments carry payout status, platform fee and a transfer reference. | These are typed in by hand. There is no automatic transfer to an owner's bank account, and **owners cannot see their payouts at all** — the panel has no such page. |

### B. Not built — no server side yet

The screens exist and correctly show empty states. They are unbuilt, not broken.

| Feature | Status |
| --- | --- |
| **In-app notifications** | No table, no endpoints. The bell opens an empty list. |
| **Coupons / discount codes** | No table, no endpoints. |
| **Rewards, points, wallet withdrawal** | No table, no endpoints. |
| **City list and price-band presets** | Returned empty; the app filters on what it has instead. |
| **Push notifications (FCM)** | Phase 2 by plan. Not started. |
| **Review moderation** | An admin can delete a review but cannot hide or approve one. |
| **Settings pages** | Privacy, Language, About and Terms of Service are dimmed placeholders with nothing behind them. |

### C. Waiting on an account, a key, or one command

No development work — these are decisions and credentials.

| Item | What is needed |
| --- | --- |
| **Venue prices** | **Every ground is still ₹0, so nothing is bookable.** The script is written and tested; it needs running once against the live database. |
| **Razorpay live keys** | The app is on a **test** key. Test mode offers no real UPI — almost certainly why UPI looked broken. Needs completed KYC. |
| **Twilio (SMS)** | Unconfigured. OTP codes print to the server console. The demo bypass **must be switched off before launch.** |
| **DLT registration** | Required in India before any transactional SMS can be sent. |
| **Google Maps key** | Pending. |
| **Android app ID** | Still the `com.example` placeholder; must change before a Play Store release. |

### D. Engineering debt worth knowing about

| Item | Note |
| --- | --- |
| **No automated tests on the server or the panel** | The customer app has ~170. The other two have none, so their changes are verified by hand. |
| **Dead pricing column** | `price_per_half_hour` is kept for one release as a record of the old per-sport figures, then should be removed. |
| **Screens that have grown too large** | The ground detail and booking flow screens are the two worth splitting up before more is added to them. |
