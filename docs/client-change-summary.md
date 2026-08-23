# What we changed — Playsher

**Period:** 17 – 21 August 2026 · **73 changes** across the customer app, the owner
and admin panel, and the server.

This is a plain-English account of the work. It is written for a non-technical
reader, so it describes what a person using Playsher would notice, not how it was
built. The last section lists what is still outstanding, honestly.

---

## In one paragraph

We started from a version where the core journey did not work: a customer could
not complete a booking reliably, prices showed as ₹0, the ground page hid its own
title, reviews could never be posted, and past bookings never moved out of
"upcoming". We fixed the booking and payment path end to end, then went through
every screen that was showing wrong or empty data and connected it to the real
information. Alongside that we gave ground owners the tools they were missing
(slot control, pricing, schedules), gave you as the platform owner real
administrative control (edit any account, reset passwords, manage your own admin
team, force app updates), and closed a set of security holes that would have let
one ground owner interfere with another's venue. We also set up automated app
builds for Android and iOS, and made the panel installable like a normal app.

---

## 1. Booking and payment — the part that was broken

**Retrying a failed payment used to book you twice.** If a payment failed and the
customer tapped again, the app created a brand-new booking instead of retrying the
existing one. That either produced a confusing "these slots are already booked"
error — blaming the customer for their own abandoned attempt — or quietly left an
extra unpaid booking behind. Booking and paying are now two separate steps: a retry
re-opens payment for the *same* booking.

**Abandoned checkouts used to lock slots forever.** If someone opened the payment
screen and closed it, those slots were held permanently with no booking to show for
it — which is why slots disappeared for no visible reason. Unpaid holds now expire
after **5 minutes**, the slots go back on sale automatically, and the customer sees
a live countdown while they pay. When it lapses, they get a clear "session expired"
message instead of a dead Pay button.

**Checkout quoted ₹0 while the confirmation quoted the real amount.** The app was
reading a price field the server never sent. Prices are now read from the same
place the server charges from, so what the customer sees is what they pay.

**Pay at ground now takes a 10% advance online** (minimum ₹10), with the balance
collected at the venue. The exact split is stored on the booking, so the receipt,
the owner's list and any later reconciliation all quote the same figures rather
than each recalculating.

**Time slots that had already passed were still on sale.** Two separate faults: the
server was reading its own clock (which runs on UK time) rather than Indian time,
so at 2:51 pm IST it believed it was 9:21 am and happily offered every slot from
10 am onwards — all already played. Everything now judges "has this slot started?"
in the venue's own timezone.

**Confirmation and receipt.** The success screen showed the date but never the
time, and printed the date raw as `2026-08-20`. It now shows the venue, sport,
date, time window, duration, what was paid and what is still owed at the ground —
and can be **shared** as a plain-text summary with a maps link, so whoever receives
it can navigate there.

---

## 2. Prices — one price, one place

Cards were advertising venues as **free** when they were not. The old system priced
each sport separately, and the card showed the *cheapest* sport — so one sport
nobody had priced yet was enough to put ₹0 on the whole venue while the detail page
quoted the real figure.

Pricing now lives on the **venue**: one price for one 30-minute slot, the same for
cricket and badminton at that ground. That is a deliberate trade-off — it removes
the failure mode entirely.

- A venue with no price set shows **"Price on request"**, not ₹0 (₹0 reads as free).
- A venue with no price **cannot be booked** — the server refuses it rather than
  taking someone through checkout only to fail at payment.
- Only the server ever calculates money. The app never sends an amount.
- Owners can price their own grounds; you as admin can price any ground.

**The panel was also billing in the wrong currency** — Pakistani rupees (₨) appeared
in 26 places across eight pages. It is Indian rupees (₹) throughout now.

---

## 3. The customer app

**Home screen.** Replaced the logo and a dead city label with a real greeting and a
tappable location chip. Grounds now show **how far away they are** and the list
sorts nearest-first. Each venue card carries a **live weather chip** — and it
escalates to a warning only where it matters: rain at an *uncovered* ground.

**Finding a venue.** The "Apply Filters" button genuinely did nothing before —
every choice was thrown away on the way out. Filters now work (sport, distance,
price, rating, amenities, covered), search matches venue name, locality, city,
address or sport, and searching no longer fires a request on every keystroke.
Cards now show the locality, per-slot price, **how many slots are left today**,
whether the venue is covered, distance and rating.

**Ground page.** The venue's own name was rendering *underneath* the hero photo —
which is what made the page read as stuck. Booking was also unreachable: the page
waited for you to tap a sport pill with nothing suggesting you should, so there was
no calendar, no slots and no Book Now button on arrival. Both fixed. The photo
gallery also could not be swiped at all — an invisible decorative layer was
swallowing the gesture.

**Reviews.** Nothing in the system ever marked a booking as finished, so every
booking stayed "upcoming" forever, the Past tab was permanently empty, and a review
could never be posted by anyone. Finished bookings now retire automatically, and
there is a real review flow: customers who actually played at a venue can rate it,
one review per venue, and the app checks eligibility *before* offering the form
rather than after.

**Games.** "Host a Game" collected details, said "Game published!" and did nothing
— no game was ever created. It now works properly, starting from a booking the
player already holds. Games also showed ₹0 at an unnamed ground with no date; they
now carry the real venue, date, time and a **per-player price** calculated by the
server from the booking total split across the open seats.

**My Bookings.** Was missing the sport, the time, and correct ordering, and the
back button was a dead end. All fixed: newest first, sport glyph, full time range
with duration, and what is still owed at the venue. Booking detail also gets a
**"Directions"** button.

**Profile.** There was no way to edit it — the pencil icon on the avatar looked like
a button and did nothing. There is now a real edit screen for name and email. Mobile
number stays read-only on purpose: it is the login identity and changing it needs a
fresh OTP.

**Login.** The three login screens were **white text on a white background** — the
login flow was unreadable. Fixed, along with the OTP boxes, which had a grey slab
painted across them.

**Back button.** From any tab, Android back returns to Home rather than closing the
app; from Home it takes two presses. During booking, back was disabled through most
of the payment flow — which is exactly why "back does nothing" was reported.

**Look and feel.** Light and dark mode both work properly now (the app used to
default to dark and several screens only worked in dark). Text no longer overflows
or clips when someone raises their phone's font size. Loading states are proper
skeleton placeholders shaped like the content that replaces them, rather than
spinners. Every button reachable by finger meets the 44-pixel minimum. Nothing in
the app relies on colour alone to convey status, so it still reads on a greyscale
screen.

**Fake data removed.** The notification bell showed a permanent unread badge of 2
from four invented notifications. Grounds with no photo were falling back to a
random stock image from the internet — a photo of a venue the customer was about to
pay for. Both gone.

---

## 4. What ground owners can now do

- **See and control their slots.** There was no slot screen at all: owners could not
  view a day's slots or close one for maintenance. There is now a Slots tab —
  pick a date and sport, tap a slot to open or close it.
- **Edit pricing and limits without destroying anything.** Previously the only way
  to change a sport's price was to delete the sport and re-add it — which silently
  wiped that sport's entire weekly schedule and every generated slot, leaving
  customers with "no slots available" and nothing in the panel explaining why.
  There is now a proper edit form.
- **See why a ground is unbookable.** A sport with no open day in its schedule now
  says so on the row: *"No weekly schedule — customers see no slots available."*
- **The booking on/off switch works.** It was writing to a column that does not
  exist, so it did nothing and the status always read "Closed".
- **Change their own password**, and mark a ground as covered, with area and city.

---

## 5. What you can now do as admin

- **Edit anything.** "Every data is not configurable" was literally true — the
  edit endpoints did not exist. You can now edit ground owners, customers and
  grounds, including reassigning a ground to a different owner.
- **Reset a forgotten password** for a ground owner. There was previously no
  recovery path at all. Resetting signs that person out everywhere, as it should.
- **Manage your admin team.** Adding a colleague used to mean sharing a single
  master password that grants full platform access and cannot be revoked for one
  person. There is now a proper Admins screen: create, edit, deactivate, reset
  passwords, with a **super-admin tier** above regular admins. Accounts are
  deactivated rather than deleted so the audit trail survives, and the system
  will not let you lock yourself out — you cannot deactivate yourself, demote
  yourself, or remove the last remaining admin.
- **Force app updates.** You can now set, per platform, the newest version (shows a
  dismissible "update available" nudge) and the minimum supported version (blocks
  the app until the user updates). There is a kill switch on each, so a wrong
  threshold can be undone without shipping anything. The system refuses to set a
  minimum higher than the latest build, which would lock out every user including
  current ones.
- **The admin bookings list was blank.** Every cell showed a dash because the page
  was reading fields under the wrong names. Fixed.
- **Install the panel like an app.** The panel now installs to a phone home screen
  or desktop and opens without a browser bar. Business data is deliberately never
  cached — on a shared machine, one admin's records must never be served to the
  next person. Offline it tells you the connection is down, so a failed save reads
  as "no signal" rather than "the app is broken".

---

## 6. Security — problems found and closed

These were real holes, all now closed and tested:

- **A ground owner could self-approve their own venue**, bypassing your review —
  and the public list shows approved grounds, so that would have published an
  unmoderated venue.
- **Any ground owner could edit another owner's venue** — reprice it, reopen slots
  they had closed for maintenance, delete their whole day, or move a slot (with
  its bookings attached) onto a different ground.
- **Anyone could review any venue** they had never been to, by leaving one field
  out of the request.
- **A customer could mark their own account as verified** or change the mobile
  number their account logs in with.
- **Changing a password did not end existing sessions**, so whoever had stolen the
  account kept it. Password changes and account deactivations now revoke every
  session immediately — which is the entire point of changing a password you
  believe is compromised.
- **Deleted grounds kept answering requests.**
- **The logs were printing login tokens, request contents, and customers' names and
  mobile numbers.** No longer.

---

## 7. Stability and infrastructure

**The server would not start at all** at two points — once from a bad code merge,
once because the payment library was being set up before it had its keys and threw
on the spot. Both fixed, and the payment endpoints now return a readable "payments
are not configured" message rather than taking the entire API down.

**The database was quietly damaging itself on every restart.** Each start left
another duplicate copy of the same index behind — 124 grew to 133 in a single
restart, and the customer table had *eight identical copies* of the same one. The
database allows 64 per table, so this was a countdown to the login tables failing
outright. Stopped at the source, and the 54 accumulated duplicates were cleaned up.

**The database structure now lives in one file with a panel behind it.** Structural
changes used to be hand-typed SQL applied manually, and the two had drifted — three
changes had never been applied to the live database and one only partly, which is
why some queries were failing in production. There is now a Database Schema screen
that shows exactly what differs between the intended structure and the live
database, classifies each change as safe, risky or unsafe, and applies it on
confirmation. **It can never delete a table or a column** — there is no code path
that does, under any setting.

**Automated app builds.** Android APKs and iOS IPAs now build automatically from
the code, with the signing setup documented and scripted (including a route that
works without owning a Mac). The iOS app identifier was `com.example.playsherApp`,
which Apple rejects outright; it is now `com.playsher.app`.

**Hosting.** A series of fixes to get the API running correctly on Vercel and the
API documentation page loading rather than showing blank.

---

## 8. Testing

The mobile app now has **19 test files covering roughly 170 automated checks** —
there were almost none before, and the one that existed was failing. They cover the
booking data, pricing, filters, navigation, the update prompt, weather, distance,
and layout guards that fail if a screen overflows on a small phone or at a larger
font size. On the server side, individual pieces of work were verified with between
7 and 180 checks each, run against a real throwaway database where the change
touched data.

---

## 9. Still outstanding — needs action outside the code

These are not defects; they are things waiting on accounts, keys or a decision.

| Item | Status |
| --- | --- |
| **SMS for OTP (Twilio)** | Not configured. OTP codes currently print to the server console instead of being texted. A demo bypass setting exists and **must be switched off before launch.** |
| **Razorpay live keys** | The app is on a **test** key. Test mode does not offer real UPI, which is the most likely reason UPI appeared not to work — the app-side work for UPI is done. Live keys need completed KYC on the Razorpay dashboard. |
| **Venue prices** | Every ground in the live database is currently at ₹0, so nothing is bookable. A one-time script is written and ready to carry the old per-sport prices up to each venue; it needs to be run once against the live database. |
| **Google Maps key** | Pending. |
| **DLT registration** | Pending (required in India before transactional SMS can be sent). |
| **Android app identifier** | Still `com.example.playsher_app` and must be changed before a Play Store release. |
| **Push notifications** | Phase 2, not started. |
| **Coupons, rewards, in-app notifications** | The server endpoints do not exist yet. The screens exist and correctly show empty states — they are not broken, they are unbuilt. |
