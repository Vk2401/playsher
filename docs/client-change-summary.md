# What we changed — Playsher

**17 – 21 August 2026 · 73 changes** across the customer app, the owner and admin
panel, and the server.

---

## The short version

The core journey did not work. You could not finish a booking reliably, prices
showed as ₹0, the ground page hid its own name, reviews could never be posted,
and finished matches never left "upcoming".

We fixed the booking and payment path end to end, reconnected every screen that
was showing wrong or empty data, gave owners the tools they were missing, gave
you real admin control, and closed seven security holes.

---

## The six things that were actually broken

| | Before | Now |
| --- | --- | --- |
| **Payment retry** | Tapping again after a failed payment created a *second* booking | Retry re-opens payment for the same booking |
| **Abandoned checkout** | Slots locked forever, with no booking to show for it | Held 5 minutes, then released automatically |
| **Checkout price** | Quoted ₹0 while the receipt quoted the real amount | One price, the one the server charges |
| **Past slots** | Still on sale — the server read UK time, not Indian time | Judged in the venue's own timezone |
| **Reviews** | Impossible for anyone — bookings never finished | Finished bookings retire; customers who played can rate |
| **Host a Game** | Said "Game published!" and created nothing | Creates a real game from a booking you hold |

---

## Prices

Cards were advertising venues as **free** when they were not: the old system
priced each sport separately and the card showed the cheapest, so one unpriced
sport put ₹0 on the whole venue.

Pricing now lives on the **venue** — one price for one 30-minute slot. An
unpriced venue says **"Price on request"** and cannot be booked, rather than
reading as free and failing at payment. Only the server calculates money.

The panel was also billing in **Pakistani rupees (₨)** in 26 places. It is ₹
throughout now.

---

## New for customers

- **Distance and nearest-first sorting** on the home screen, plus a live weather
  chip — which warns only where it matters: rain at an uncovered ground.
- **Filters that work.** "Apply Filters" previously discarded every choice.
  Search now matches venue, locality, city, address or sport.
- **Cards worth reading** — locality, per-slot price, slots left today, covered
  or not, distance, rating.
- **The ground page works.** The venue name was rendering under the photo, the
  gallery could not be swiped, and booking was unreachable on arrival.
- **Real bookings list** — sport, time range, duration, what is still owed.
  Shareable receipt with a maps link, and a Directions button.
- **Profile editing**, which did not exist. The pencil icon was decorative.
- **A readable login.** The three login screens were white text on white.
- **Back behaves.** It was disabled through most of the payment flow.
- Light and dark both work; text no longer clips at larger font sizes; the fake
  notification badge and the random stock photos are gone.

---

## New for ground owners

- **A Slots screen** — pick a date and sport, open or close any slot. There was
  none before.
- **Edit pricing without destroying anything.** The only way to change a price
  used to be deleting the sport, which silently wiped its whole schedule and
  every slot — that is why grounds went dark with no explanation.
- **A reason when a ground is unbookable**: *"No weekly schedule — customers see
  no slots available."*
- **The booking on/off switch works.** It was writing to a column that does not
  exist.
- Own password change; covered / area / city on a ground.

---

## New for you as admin

- **Edit anything** — owners, customers, grounds, including reassigning a ground.
  The edit functions simply did not exist on the server before.
- **Reset a forgotten password.** There was no recovery path at all.
- **Manage your admin team** — create, deactivate, reset, with a **super-admin
  tier**. Adding a colleague used to mean sharing one master password that could
  not be revoked for one person. You cannot lock yourself out.
- **Force app updates** — set the newest version (a nudge) and the minimum
  supported version (a block), per platform, each with a kill switch.
- **The bookings list was blank** — every cell showed a dash. Fixed.
- **Install the panel like an app**, on a phone or desktop.

---

## Security and stability

**Seven holes closed:** an owner could approve their own venue past your review;
any owner could edit, reprice or delete another owner's slots; anyone could
review a venue they had never visited; a customer could self-verify or change
their login number; password changes did not end stolen sessions; deleted
grounds still answered; and the logs were printing login tokens and customers'
mobile numbers.

**The server would not start** at two points — both fixed, and payments now
report themselves unconfigured rather than taking the whole service down.

**The database was damaging itself on every restart**, leaving duplicate indexes
behind — 124 became 133 in one restart, with eight identical copies on the
customer table against a hard limit of 64. Stopped, and 54 duplicates cleaned up.

**Database changes are now a screen, not hand-typed commands.** It shows what
differs, marks each change safe or risky, and **can never delete a table or
column.**

**Automated Android and iOS builds**, with Apple signing scripted. Also: the iOS
app ID was still Apple's rejected `com.example` placeholder.

**~170 automated tests** on the app, where there were effectively none.

---

## Still outstanding — needs a decision or an account

| Item | Status |
| --- | --- |
| **Venue prices** | **Every ground is still ₹0, so nothing is bookable.** A one-time script is ready and needs running once on the live database. |
| **Razorpay live keys** | On a **test** key. Test mode does not offer real UPI — that is almost certainly why UPI looked broken. Needs completed KYC. |
| **SMS for OTP (Twilio)** | Not configured; codes print to the server console. The demo bypass **must be off before launch.** |
| **DLT registration** | Pending — required in India before any transactional SMS. |
| **Google Maps key** | Pending. |
| **Android app ID** | Still the `com.example` placeholder; must change before a Play release. |
| **Push notifications** | Phase 2, not started. |
| **Coupons, rewards, notifications** | No server side yet. The screens correctly show empty states — unbuilt, not broken. |
