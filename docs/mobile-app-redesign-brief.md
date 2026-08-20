# Playsher Mobile App — Redesign & Booking Fix Brief

**Purpose of this file**: a self-contained brief for generating a Claude Design canvas (or handing to any designer) for the Flutter customer app. It carries every real API field the UI can show, the current design system (tokens + widget library) so nothing gets re-invented, the full screen inventory, and a prioritized bug list — led by the mechanism behind the reported "booking is broken."

**Rule for whoever designs from this file**: follow `docs/mobile-ui-guidelines.md` exactly — tokens only, 44px touch targets, mandatory loading/empty/error states, GoRouter push/go semantics, one entrance animation per screen. Do not invent data fields beyond what's listed in §3. Where a screen's backend data doesn't exist yet (§3.1), design it as an explicit empty/"coming soon" state, not a populated mockup.

---

## 1. Product context

Sports-ground booking platform, multi-city India. Three roles (`user`, `ground_owner`, `admin`); this brief covers only the **customer app** (`role=user`, OTP login, Flutter/Riverpod/GoRouter). Backend is Node/Express/Sequelize/MariaDB; every response is `{ success, message, data, pagination? }`, fields snake_case.

---

## 2. Current design tokens (reuse — do not reinvent)

### Colors (`lib/core/app_colors.dart`)

| Token | Dark | Light |
|---|---|---|
| `background` | `#000000` | `#F5F5F5` |
| `card` | `#121212` | `#FFFFFF` |
| `input` | `#1A1A1A` | `#F0F0F0` |
| `elevated` | `#111111` | `#FFFFFF` |
| `border` | `#2A2A2A` | `#E0E0E0` |
| `textPrimary` | `#FFFFFF` | `#1A1A1A` |
| `textSecondary` | `#A0A0A0` | `#757575` |

Brand (same both themes): `primary #00D261`, `accent #CCFF00`, `error #FF4D4D`, `star #CCFF00` (aliased to accent). Primary/accent fills take **black** foregrounds, never white.

### Geometry (`theme.dart`)
Card radius 16 · chip 20 · input 12 · buttons 14 · bottom sheet 24 (top corners) · dialog 16. Buttons floor at 52px height (`minimumSize: Size(double.infinity, 52)`).

### ⚠️ Token bugs to fix as part of this redesign
- **`AppTheme`'s legacy static aliases are dark-only** and still used in `otp_screen.dart`, `phone_screen.dart`, `register_screen.dart` (11 usages) — these must be replaced with `context.colors.*` per guideline §2.
- **Invisible text bug, functional not cosmetic**: `phone_screen.dart:41` and `otp_screen.dart:100,102` hardcode `backgroundColor: Colors.white`, while the headline text on those same screens uses `AppTheme.textPrimary` (`otp_screen.dart:120`, `phone_screen.dart:67`), which resolves to `#FFFFFF` always. **"Welcome to Playsher" and "Verify OTP" render as white text on a white background in both themes** — the first two screens a new user sees are broken. Fix this token issue before/alongside any visual redesign of these screens.

---

## 3. Existing widget library — reuse-first inventory

| Widget | Renders | Variants |
|---|---|---|
| `GroundCard` | Ground listing card | `wide: true/false` → `_WideCard` (vertical, carousels) / `_HorizontalCard` (row, lists) |
| `BookingCard` | Booking summary card | — |
| `GameCard` | Open-game card w/ fill `ProgressBar` | — |
| `CoachCard` | Coach card w/ award badge | — |
| `ReviewCard` | Single review | — |
| `NotificationCard` | Dismissible notification row | type-based icon/color switch |
| `SlotTile` | Bookable slot chip | — |
| `StripedSlotTile` | Alt slot tile, diagonal-stripe booked pattern | **dead code — unused anywhere, remove or reconcile with `SlotTile`** |
| `SportChip` | Selectable pill | optional emoji |
| `StatusBadge` | Colored label pill | `.bookingStatus(status)`, `.gameLevel(level)` factories |
| `TrustBadge` | Icon+label pill | `.verified()`, `.quality()`, `.certified()` |
| `RatingStars` | 5-star row | optional numeric label |
| `ParticipantAvatar` | Circular avatar | HOST tag / joined-check / empty "+" slot |
| `ProgressBar` | Labeled linear progress | — |
| `StatGrid` | Row of stat cells | takes `List<StatItem>` |
| `SectionHeader` | Title + "See all" | — |
| `StickyBottomBar` | Price + CTA bar, double-submit guard | — **currently reinvented instead of reused in both booking screens, see §5** |
| `GlassmorphicButton` | Frosted-glass tap surface | — |
| `AnimatedListItem` | Staggered entrance | index-based delay |
| `ErrorView` | Icon + message + Try Again (44px) | — |
| `ShimmerBox` / `GroundCardShimmer` / `ListShimmer` | Skeleton loaders | in `shimmer_loader.dart` |

**Gap**: no `*Shimmer` exists for `BookingCard`, `GameCard`, `CoachCard`, or slot tiles — several screens fall back to a bare, ungoverned spinner instead (see §5). Add shimmer variants for these as part of the redesign.

---

## 4. Screens inventory (24 screens, 6,446 lines total)

| Screen | Route | Lines | Purpose |
|---|---|---|---|
| `splash_screen.dart` | `/splash` | 121 | Logo splash, session check |
| `onboarding_screen.dart` | `/onboarding` | 253 | 3-page swipe intro |
| `phone_screen.dart` | `/login` | 162 | Mobile entry, send OTP |
| `otp_screen.dart` | `/otp` | 226 | OTP verify, resend timer |
| `register_screen.dart` | `/register` | 158 | New-user name/email |
| `location_screen.dart` | `/location` | 275 | GPS/manual location |
| `main_shell.dart` | shell | 51 | Bottom nav, 5-branch indexed stack |
| `home_screen.dart` | `/home` | 427 | Banner, sports, nearby/popular grounds |
| `explore_screen.dart` | `/venues` | 228 | Ground search + filter |
| `games_screen.dart` | `/games` | 268 | My/Open games tabs |
| `coaching_screen.dart` | `/coaching` | 142 | Coach list |
| `profile_screen.dart` | `/profile` | 372 | Account summary/settings |
| **`ground_detail_screen.dart`** | `/grounds/:id` | **890** | Gallery, sport/date/slot picker → booking bar |
| **`booking_flow_screen.dart`** | `/book/:groundId` | **662** | Payment method + Razorpay checkout |
| `booking_confirm_screen.dart` | `/booking-confirm` | 229 | Success/confirmation |
| `bookings_screen.dart` | `/my-bookings` | 149 | Upcoming/Completed tabs |
| `booking_detail_screen.dart` | `/bookings/:id` | 370 | Booking detail + cancel |
| `game_detail_screen.dart` | `/games/:id` | 179 | Game detail + join |
| `host_game_screen.dart` | `/host-game` | 247 | Create-a-game form |
| `coach_detail_screen.dart` | `/coaching/:id` | 173 | Coach detail |
| `settings_screen.dart` | `/settings` | 182 | Theme toggle, account |
| `saved_turfs_screen.dart` | `/saved-turfs` | 78 | Favorited grounds |
| `notifications_screen.dart` | `/notifications` | 94 | Notification list (stub data, §3.1) |
| `venue_filter_screen.dart` | `/venue-filter` | 510 | Sport/price/distance/rating/amenity filters |

`ground_detail_screen.dart` (890) and `booking_flow_screen.dart` (662) are, by far, the two most in need of extraction into widgets per guideline §1 — both are also the two files carrying the booking bugs in §5.

---

## 5. API data model — exact fields per domain

*(snake_case on the wire; pagination meta is `{ total, page, limit, totalPages }` — note `totalPages` is the one camelCase exception)*

**Auth** — `POST /auth/send-otp {mobile}`, `POST /auth/verify-otp {mobile,otp}` → `{new_user}` or `{access_token,refresh_token,user:{id,name,mobile,email}}`, `POST /auth/complete-registration {name,mobile,email?}`.

**Grounds** — `GET /grounds` (`sport_id,lat,lng,radius_km,page,limit`) / `GET /grounds/:id` → `id,name,about,description,latitude,longitude,address,venue_rules,is_approved,is_active,owner_id,owner:{id,name,email,mobile},images:[{id,image,is_primary}],amenities:[{id,name,icon,type}],groundSports:[{id,price_per_half_hour,min_slots,max_slots,player_counts,cancellation_policy,sport:{id,name}}]`.

**Slots** — `GET /ground-sports/:gsId/slots?date=` → `id,ground_sport_id,slot_date,slot_start_time,slot_end_time,is_available`.

**Bookings** — `GET /bookings` (own) → bare rows only: `id,user_id,ground_sport_id,slot_date,slot_time_from,slot_time_to,total_amount,is_game,is_canceled,cancellation_reason,payment_id,booking_reference,payment_method,status`. `GET /bookings/:id` → same + nested `user,groundSport:{ground:{...}},slots[],paymentRecord`. `POST /bookings {ground_sport_id,slot_date,slot_ids[],is_game?,payment_method?}`. `PATCH /bookings/:id/cancel {cancellation_reason?}`.

**Games** — `id,game_name,hosted_by_user_id,hosted_by_ground_owner_id,booking_id,max_participants,game_level (newbie|beginner|intermediate|advanced|professional|ultra_professional),description,image,visibility (public|private),participants:[{user_id,status}]`.

**Coaches** — `id,name,sport_name,experience_years,level,mobile,email,about,experience_details,awards,latitude,longitude,availability,qualities,profile_picture`.

**Reviews** — `id,reviewed_by_user_id,review_type (ground|sport|coach|application),ground_id,ground_sport_id,coach_id,booking_id,rating (1-5),comment,reviewer:{id,name}`.

**Favorites** — `GET /favorites` → `{id,user_id,ground_id,ground:{...,images:[primary]}}`. `POST/DELETE` by `ground_id`.

**Sports** — `id,name,short_description,image,place_type (ground|court),sports_type (indoor|outdoor)`.

**Amenities** — `id,name,icon,type (venue|sport)`.

**Profile** — `GET/PUT /profile` → `id,name,mobile,email,profile_picture,current_latitude,current_longitude,is_verified` + `sportPreferences:[{sport:{id,name}}]`.

**Payments** — `POST /payments/razorpay/create-order {booking_id}` → `{order_id,amount,currency,key_id,payment_id}`. `POST /payments/razorpay/verify {razorpay_order_id,razorpay_payment_id,razorpay_signature}` → `{payment,booking}`.

### 5.1 Backend gaps to design around (no data exists — design empty states only)

Confirmed **zero backend routes/models** for: **notifications, coupons, rewards, cities (no city concept on Ground at all — only lat/lng + free-text address), price filters, dashboard/home feed**. Flutter's `ApiClient` stubs these to empty data. Design these screens as explicit empty-state/"coming soon" patterns — do not mock up populated content that the API can't produce yet.

### 5.2 Other structural quirks worth designing around
- `GET /grounds` ignores a `search` query param — no server-side search exists yet.
- `GET /bookings` (list) returns **unnested** rows — no ground name/photo without a follow-up detail call per item. A bookings-list screen's card design should tolerate showing only what's in the bare row, or the client needs a join step (flag to backend team).
- No "popularity" sort exists server-side — "Popular Grounds" is just `limit:10` with no ordering.
- Coach `sport_name` filter is accepted by the Flutter client but ignored server-side.

---

## 6. Booking flow — root cause of "booking is broken" + full fix list

This is the P0 section. Trace: `GroundDetailScreen` → slot selection → `BookingFlowScreen` → Razorpay → `BookingConfirmScreen`.

### 🔴 Critical — retrying a failed payment re-books instead of resuming
`booking_flow_screen.dart:55` `_confirmBooking()` unconditionally calls `createBooking(...)` (line 64) **every time it runs**, with no check for an already-pending booking. On Razorpay failure (`_onPaymentError`, lines 175-181), the same button re-enters `_confirmBooking()` from scratch on retry — creating a **second booking** for the same ground/date/slots while the first attempt's `_pendingBookingResult` (line 99) is silently discarded. This either fails confusingly ("slots already booked," blaming the user's own orphaned attempt) or succeeds and leaves an orphaned unpaid booking. **This is almost certainly the actual mechanism behind the reported bug** — fix: track the pending booking/order id and resume payment against it on retry instead of creating a new booking.

### 🔴 Critical — dead external-wallet handler can hang the loader forever
`_onExternalWallet` (line 183-185) does nothing — no state change, no navigation. If a wallet path doesn't subsequently fire success/error, `_loading` stays `true` indefinitely with the CTA spinner spinning and back navigation disabled (line 206). Needs a real handler or at minimum a timeout/fallback.

### 🟠 High — Razorpay checkout prefill always blank
Lines 122-125 hardcode `contact:''`, `email:''` instead of pulling from the already-authenticated user — the user just verified their mobile via OTP to reach this screen and has to re-type it into Razorpay's sheet.

### 🟠 High — booking detail always claims "Pay at Ground"
`booking_detail_screen.dart:163` hardcodes `value: 'Pay at Ground'` regardless of the booking's actual `payment_method` — an online-paid booking shows the wrong payment method when viewed later. (`booking_confirm_screen.dart` gets this right immediately after payment, lines 88/100 — the bug is only in the later detail view.)

### 🟠 High — dead favorite button on ground detail
`ground_detail_screen.dart:120-123` — the hero header's heart icon has `onPressed: () {}`. Unlike `GroundCard`'s heart, this one does nothing; a user can't favorite a ground from its own page.

### 🟡 Medium — both booking screens reinvent `StickyBottomBar`
`ground_detail_screen.dart`'s `_BookingBar` (823-890) and `booking_flow_screen.dart`'s `bottomNavigationBar` (371-430) both hand-roll the price+CTA+safe-area bar instead of reusing the shared widget — direct §1 guideline violation. `coach_detail_screen.dart`/`game_detail_screen.dart` do this correctly; use them as the reference.

### 🟡 Medium — touch targets under 44px
Ground detail's back button (98-112) and (dead) favorite button (114-124) are sized to their icon with only `margin`, not an explicit 44×44 hit area — same class of bug the guidelines doc already flags for `GroundCard`'s hearts (30×30/26×26, still unfixed) and the home screen's notification bell (40×40, still unfixed).

### 🟡 Medium — OTP verify loader is inline, not full-screen (self-documented shortcut)
`otp_screen.dart:170` literally comments `// Verifying indicator (inline, not full-screen)` above a row spinner — exactly the violation guideline §6 names explicitly for auto-firing OTP verify.

### 🟡 Medium — no shimmer / bare spinners
`saved_turfs_screen.dart:20`, `coach_detail_screen.dart:22`, `game_detail_screen.dart:24` use bare `CircularProgressIndicator()` (uncolored); `booking_detail_screen.dart:93-95` at least colors it but is still not a shimmer skeleton — all violate guideline §5.

### 🟢 Lower priority / hygiene
- Deprecated `.withOpacity(...)` used throughout the booking-adjacent files (`ground_detail_screen.dart`, `booking_flow_screen.dart`, `booking_confirm_screen.dart`, `booking_detail_screen.dart`, plus `otp_screen.dart`/`phone_screen.dart`) instead of `.withValues(alpha:)` used elsewhere — signals this is the least recently touched part of the app.
- Magic-number spacer (`ground_detail_screen.dart:494`, `SizedBox(height:100)`) guessing at the booking bar's height instead of measuring it.
- Hardcoded info-banner blue (`booking_flow_screen.dart:291,293,298`) not sourced from `AppColors` — promote to a token if an "info" semantic color is wanted app-wide.
- `booking_confirm_screen.dart:41-46` defensively reads `booking['booking_reference'] ?? booking['id'] ?? booking['booking_id']` — three aliases guessed at; reconcile with the actual API contract (`booking_reference` per §5) instead.
- `StripedSlotTile` is unused dead code — remove or merge into `SlotTile`.
- **Not a bug**: navigation into/out of the confirm screen correctly uses `context.go(...)` everywhere (never `push`) — the usual "back returns to a spent payment screen" failure mode does **not** occur here. Worth designing consistently with this correct pattern rather than assuming it's broken.
- Unrelated to booking but severe: `ApiClient`'s Dio interceptor unconditionally `print()`s full request/response bodies and a truncated bearer token on every call (`api_client.dart` lines 30-91) — ships to production builds as-is. Flag for a hardening pass alongside the visual work.

---

## 7. Guideline compliance checklist (condensed — full detail in `docs/mobile-ui-guidelines.md`)

- **Tokens only**: `context.colors.*` for surfaces, `AppColors.*` for brand — zero hardcoded `Color(0xFF…)`/`Colors.grey`/`Colors.white`/`Colors.black` (scrims over images excepted). No `AppTheme.*` legacy statics in new/touched code.
- **44×44 minimum touch targets** on every tappable, including icon-only buttons.
- **Safe areas**: one inset strategy per screen edge, never doubled. `StickyBottomBar` already adds bottom inset — don't add a second one, and don't hand-roll a replacement.
- **One scrollable per screen** — use `CustomScrollView`+slivers when mixing fixed and scrolling regions.
- **Loading/empty/error are mandatory** on every async provider watch — shimmer shaped to the content, `ErrorView` with `onRetry`, never a bare spinner or endless blank state.
- **No double-submit**: async CTAs disable while pending, bound to notifier state not a local bool.
- **Visible wait from commit to result** for OTP verify, booking create, payment, join-game — full-screen/overlay where the button spinner alone isn't visible (e.g. under the keyboard).
- **GoRouter only**: `push` for back-able children, `go`/`pushReplacement` for result/confirmation screens and anything that redirects forward on mount.
- **Motion**: 100–220ms, one entrance animation per screen, never suppress looping progress indicators.
- **Accessibility**: `Semantics`/`tooltip` on every icon-only tappable; never convey state by color alone.

---

## 8. Scope for the Claude Design canvas

Recommended artboard set, in priority order matching the bug severity above:

1. **Booking flow (P0)** — ground detail's slot picker section, booking flow/payment screen, booking confirm, booking detail — redesigned around the fixed retry/resume behavior, with the favorite button and back/favorite touch targets corrected, `StickyBottomBar` used instead of reinvented, real Razorpay prefill reflected in the payment screen's user-context card.
2. **Auth (P0, token bug)** — phone entry, OTP verify (with a full-screen verifying state, not inline), register — fixed to use `context.colors` and no longer render invisible text.
3. **Home / Explore / Games / Coaching / Profile (P1, visual refresh)** — apply the corrected token usage and shimmer coverage; these are functionally fine today per the audit, this tier is cosmetic/consistency work.
4. **Backend-pending screens (P2, empty-state only)** — Notifications, Coupons/Rewards, City picker, Dashboard home-feed: design the empty/"coming soon" state only, per §5.1 — do not populate with invented data.

For each artboard: show it in **both light and dark**, at **Pixel 7** width, and include the **loading + empty + error** state variants wherever the screen watches an async provider (per §7) — not just the populated/happy-path state. Label components using the exact widget names from §3 so the eventual Flutter implementation maps 1:1 back to this brief.
