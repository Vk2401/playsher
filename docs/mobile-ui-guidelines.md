# Mobile UI guidelines — Playsher Flutter app

**Read this before writing or editing any UI in `mobile_app/`.** These are the
non-negotiable front-end standards for the customer app. They are loaded into every
Claude Code session via an `@import` in `CLAUDE.md`, so "follow the mobile UI rules"
always means *this file*.

> Scope: `mobile_app/lib/screens/**`, `mobile_app/lib/widgets/**`, `mobile_app/lib/core/theme.dart`,
> `app_colors.dart`, `animations.dart` — anything that builds a `Widget`. The architecture
> rules in `CLAUDE.md` (providers, models, `ApiClient`) still apply on top of these.
>
> These are adapted from a production Capacitor/React app's front-end guidelines
> (`tanlux_webapp/docs/frontend-guidelines.md`); the rules are the same, the mechanisms are
> Flutter's. Sections marked **GAP** describe rules the codebase does not fully satisfy yet —
> new and edited code must satisfy them, and fixing an old violation you're already touching
> is in scope.

---

## 1. Use the widget library — never re-roll a component

- Reach for an existing widget in `lib/widgets/` before writing markup. Current widgets:
  `GroundCard`, `BookingCard`, `GameCard`, `CoachCard`, `ReviewCard`, `NotificationCard`,
  `SlotTile`, `StripedSlotTile`, `SportChip`, `StatusBadge`, `TrustBadge`, `RatingStars`,
  `ParticipantAvatar`, `ProgressBar`, `StatGrid`, `SectionHeader`, `StickyBottomBar`,
  `GlassmorphicButton`, `AnimatedListItem`, `ErrorView`, and the `ShimmerBox` /
  `*Shimmer` family in `shimmer_loader.dart`.
- If a widget is *close* but not enough, **extend it** (new named constructor, new optional
  prop with a safe default) rather than copying it into a screen. `GroundCard`'s `wide`
  flag switching between `_WideCard` and `_HorizontalCard` is the pattern to copy.
- A genuinely new, reusable piece belongs in `lib/widgets/` as its own file, not inline in a
  screen. Screens over ~400 lines are a smell: `ground_detail_screen.dart` (890) and
  `booking_flow_screen.dart` (662) are the two that most need sections extracted into widgets —
  extract when you touch them, don't add to them.
- Private sub-widgets (`_WideCard`, `_ImagePlaceholder`) stay in the file that uses them and
  keep the leading underscore.

## 2. Tokens only — zero hard-coded styling

- **Never hard-code a color.** Two token sources, and nothing else:
  - Brightness-dependent surfaces → `context.colors` (the `AppColorsExtension` on
    `BuildContext`): `background`, `card`, `input`, `elevated`, `border`, `textPrimary`,
    `textSecondary`. Resolve once at the top of `build`: `final colors = context.colors;`.
  - Brand/semantic constants → `AppColors.primary` (`#00D261`), `AppColors.accent` (`#CCFF00`),
    `AppColors.error`, `AppColors.star`. These are deliberately the same in both themes.
- A literal `Color(0xFF…)`, `Colors.grey`, `Colors.white` or `Colors.black` in a screen or
  widget is a defect — it breaks light/dark. The **only** legitimate literals are
  `Colors.transparent`, a `Colors.black.withValues(alpha: …)` scrim over an image, and the
  `onPrimary`/`onSecondary` black that sits on the neon `primary`/`accent` fills.
- If a new color is needed, add it to `AppColors` (both `light` and `dark` records), never to
  the component.
- **Do not read theme colors two ways.** `AppTheme`'s legacy static aliases (`AppTheme.card`,
  `AppTheme.background`, …) are **dark-only** leftovers. Never use them in new code, and swap
  them for `context.colors.*` in any file you're already editing. **GAP**: a few older screens
  still import them.
- Radii and geometry come from the theme where one exists (`cardTheme` 16, inputs 12, buttons
  14, bottom sheets 24, chips 20). Match the neighbouring value instead of inventing a third.
- Style comes from `ThemeData` in `core/theme.dart`, not from per-widget overrides. If every
  screen is passing the same `style:` to a button, the fix belongs in `theme.dart`.

## 3. Mobile-first & touch

- The app is **portrait-locked** (`main.dart`) and targets Pixel 7 / iPhone 14 first.
- **Minimum touch target 44×44 logical px.** The theme already floors buttons at 52px height.
  Any custom tappable must reach 44 — wrap a small glyph in a `SizedBox(width: 44, height: 44)`
  (or give the `GestureDetector` `behavior: HitTestBehavior.opaque` plus padding) and keep the
  *visual* circle small if the design wants it small.
  **GAP**: the favourite hearts in `ground_card.dart` are 30×30 and 26×26 tap areas, and the
  notification bell is 40×40. Fix these when you touch the file; never add a new one.
- Prefer `InkWell`/`GestureDetector` with press feedback. `AppAnimations.tapScale(…)` (0.97
  scale, 100ms) is the house press effect for cards — use it instead of a bare
  `GestureDetector` on anything card-sized.
- Every tappable that leads somewhere gets a `Semantics` label or an `IconButton`
  `tooltip`/`semanticLabel` when it has no visible text.

## 4. Safe areas & scroll containment

Notched phones, gesture bars, and a bottom `NavigationBar` in the shell — get this wrong and
content sits under the home indicator.

- A full-screen route wraps its body in `SafeArea`, **or** — when the screen has an
  edge-to-edge hero image or a `CustomScrollView` — applies the inset itself with
  `MediaQuery.of(context).padding.top / .bottom`. Pick one per screen; never stack both on the
  same edge (that double-pads).
- **A pinned bottom CTA is `StickyBottomBar`**, placed as the `Scaffold`'s
  `bottomNavigationBar` (or the last child of a `Column` whose middle is `Expanded`) — never
  inside the scrolling body, where it scrolls away. `StickyBottomBar` already adds
  `MediaQuery.padding.bottom`; do not add a second bottom padding on top of it.
- **Only the content scrolls.** One scrollable per screen. A `ListView` inside a `Column`
  inside another `ListView` is the "whole page scrolls / nothing scrolls" bug; use
  `CustomScrollView` + slivers (as `home_screen.dart` does) when a screen mixes fixed and
  scrolling regions.
- **Keyboard safety.** Any screen with a `TextField` must keep the focused field visible when
  the soft keyboard opens: keep `resizeToAvoidBottomInset: true` (the default — don't disable
  it), make the form scrollable, and never place the active input under a fixed bottom bar.
  Verify with the keyboard actually open — the keyboard case is part of "done".
- Lists that can be empty get a real empty state, and lists that can fail get `ErrorView`
  with `onRetry` wired to `ref.invalidate(theProvider)`. Never show a bare spinner forever.

## 5. Loading, empty, error — the three states are mandatory

Every `ref.watch` of an async provider handles all three. The house pattern:

```dart
grounds.when(
  data:    (list) => list.isEmpty ? const _NoGrounds() : _List(list),
  loading: () => const GroundCardShimmer(),        // never a bare CircularProgressIndicator
  error:   (e, _) => ErrorView(
    message: 'Could not load grounds',
    onRetry: () => ref.invalidate(groundsProvider(filter)),
  ),
);
```

- **Loading is a shimmer skeleton**, shaped like the content that will replace it
  (`GroundCardShimmer` and friends in `shimmer_loader.dart`). Add a new `*Shimmer` when you
  add a new card type.
- **Never surface a raw exception string to the user.** `AuthNotifier._extractError` is the
  model: map `DioException` → a human sentence. Screens show `state.error`, never `e.toString()`.
- A pull-to-refresh `RefreshIndicator` uses `color: AppColors.primary`,
  `backgroundColor: colors.card`, and invalidates the same provider keys the screen watches.

## 6. Async actions that route away — loader from commit to result

**From the moment the user commits an action until the result screen is on screen, a visible
loader is up and the screen they left never repaints.** This covers OTP verify, booking
create, Razorpay payment, and join-game.

- **No double-submit.** Any control that kicks off async work disables itself while pending:
  `onPressed: isLoading ? null : _submit`, exactly as `StickyBottomBar` does with its
  `isLoading` flag. A second tap must never fire while the first is in flight — including
  taps that navigate or pay. Bind the flag to the notifier's `isLoading`, not to a local
  `bool` you might forget to reset in a `catch`.
- **The wait must be visible where the user is looking.** A 22px spinner inside a CTA that the
  soft keyboard is covering is not feedback — OTP verify, which auto-fires on the last digit,
  needs a full-screen/overlay loader, not just the button spinner. The button spinner stays
  (it's the double-submit guard), but it is not the visible wait.
- **Leaving to another app** (Razorpay checkout): turn the loader on *before* awaiting the
  result callback, keep it non-cancelable, resolve exactly once to a definite outcome, and
  reach the result screen with `context.go`/`pushReplacement` — **never `push`**, or back
  re-enters a completed payment.
- Always `await` teardown before navigating, and guard every `setState`/navigation after an
  `await` with `if (!mounted) return;`.

## 7. Navigation

- **GoRouter only.** `context.push` / `context.go` / `context.pop`. Never `Navigator.of(context)`
  and never a raw `MaterialPageRoute` — the routes in `lib/router.dart` are the whole API.
- **A new screen means a new `GoRoute`.** Route paths are the contract; keep them plural and
  lowercase (`/grounds/:id`, `/bookings/:id`, `/games/:id`).
- **`push` vs `go`/`pushReplacement` decides what back does.** Use `push` for a child the user
  should be able to back out of. Use `pushReplacement`/`go` for a screen the user must not
  return to: any result/confirmation screen, and any screen that redirects forward on mount
  (otherwise back lands on it and it skips forward again — the treadmill that reads as "the
  back button does nothing").
- Auth gating lives **only** in the router `redirect` in `lib/router.dart`, which reads
  `authProvider`. A screen never checks "am I logged in" and pushes `/login` itself.
- The five bottom-nav branches are a `StatefulShellRoute.indexedStack` — each tab keeps its own
  stack. Don't add a sixth tab; add a route reachable from an existing tab.

## 8. Motion

- Transitions are **short and subtle**: 100–220ms, `Curves.easeOut` / `easeOutCubic`. Use the
  shared primitives — `AppAnimations.slideUpFade` for screen entrances (fade + 8% rise),
  `AppAnimations.tapScale` for press, `AnimatedListItem` for staggered list entrances.
  Don't invent a per-screen animation system.
- **One entrance animation per screen.** Stacking a screen-level fade, a list-level stagger,
  *and* a card-level fade multiplies opacities — the screen reads as "nothing happens, then it
  pops in". Pick the layer closest to the content that actually arrives.
- **Content that arrives after the screen** (a provider resolving behind a shimmer) animates on
  the container that mounts *with the data*, not on the screen root — otherwise the entrance
  plays on an empty screen and the real content snaps in unanimated.
- **Reduce Motion must never delete progress feedback.** If motion suppression is ever added,
  it must exclude looping progress indicators (shimmer loaders, spinners, the payment wait).
  Freezing a loader makes the app read as hung — a *worse* bug than the animation. Decorative
  loops (pulses, breathing) are correctly allowed to stop.
- `flutter_animate` is available; keep its use to entrance/emphasis and within the same
  duration budget.

## 9. Accessibility

- Provide accessible names: `semanticLabel` on meaningful icons, `Semantics(label: …)` around
  icon-only tappables, `excludeSemantics`/`ExcludeSemantics` for purely decorative glyphs.
- **Never convey state by color alone** — pair it with text or an icon. `StatusBadge` and
  `SlotTile` (available / selected / booked) must each be distinguishable without color.
- Respect the user's text scale: no fixed-height box that clips at 1.3× `textScaleFactor`.
  Prefer `Flexible`/`Expanded` + `overflow: TextOverflow.ellipsis` over hard heights.
- Contrast: the neon `primary`/`accent` fills take **black** foregrounds (as the theme sets),
  never white.

## 10. Before you call mobile UI work "done"

- `flutter analyze` is clean.
- No literal colors; no `AppTheme.*` legacy statics in files you touched.
- Every tappable ≥ 44px; every async CTA disables while pending.
- Loading / empty / error states all exist and were actually seen.
- Checked in **both** light and dark, at Pixel 7 and iPhone 14 sizes, with the keyboard open
  on any screen that has a text field.
