---
name: playsher-mobile-ui
description: UI craft rules and copy-paste recipes for the Playsher Flutter app — theming tokens, the widget library, 44px touch targets, safe areas and sticky bottom bars, keyboard handling, loading/empty/error states, shimmer skeletons, motion budgets, double-submit protection and accessibility. Load before building or restyling any screen or widget in `mobile_app/lib/screens` or `lib/widgets`.
---

# Playsher mobile UI

The rules live in `docs/mobile-ui-guidelines.md` (auto-loaded via `CLAUDE.md`). **This skill is
the how-to**: the exact code the rules expect. Recipes: `references/screen-recipes.md`.

## The five things that are wrong most often

1. **A literal color.** `Color(0xFF1A1A1A)`, `Colors.grey[800]`, `Colors.white` in a widget.
   → `context.colors.input` / `.textPrimary` / `AppColors.primary`. Resolve once per `build`:
   `final colors = context.colors;`. Only `Colors.transparent` and
   `Colors.black.withValues(alpha: …)` scrims are exempt.
2. **A sub-44px tap target.** A 26–30px `GestureDetector` circle (the favourite hearts) is
   unhittable in one-handed use. Keep the visual small, make the *target* 44.
3. **A missing state.** `.when` without a real `loading` skeleton or an `error` with retry.
4. **A CTA that can be double-tapped** into two bookings or two payments.
5. **A bottom bar or CTA that ignores the home indicator**, or a text field that the keyboard
   covers.

## Theming

```dart
@override
Widget build(BuildContext context) {
  final colors = context.colors;              // AppColorsExtension on BuildContext
  ...
  color: colors.card,                          // surfaces follow brightness
  border: Border.all(color: colors.border),
  style: TextStyle(color: colors.textSecondary),
  ...
  color: AppColors.primary,                    // brand — identical in both themes
}
```

`context.isDark` exists for the rare genuine branch (e.g. a nav bar that is pure black vs pure
white). Prefer a token over a branch.

Adding a token: add the field to `AppColors`, then to **both** the `dark` and `light` const
records in `core/app_colors.dart`. Never add a one-off to a widget.

Global look changes (button height, input radius, chip shape, dialog style) belong in
`core/theme.dart`'s `_build`, which is shared by `AppTheme.light` and `AppTheme.dark` — change
it once and both themes follow.

**Never use `AppTheme.card` / `AppTheme.background` / `AppTheme.textSecond`** in new code. They
are dark-only legacy aliases kept for older screens; each one is a light-mode bug waiting to
happen. Replace them when you edit a file that uses them.

## Touch targets

```dart
// Icon-only tappable: 44px target, 30px visual.
Semantics(
  label: isFavorite ? 'Remove from saved' : 'Save this ground',
  button: true,
  child: GestureDetector(
    onTap: onFavoriteToggle,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: 44, height: 44,
      child: Center(
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
          child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 16, color: isFavorite ? AppColors.error : Colors.white),
        ),
      ),
    ),
  ),
)
```

Buttons already comply: the theme floors `ElevatedButton`/`OutlinedButton` at 52px, and
`ErrorView`'s retry uses `minimumSize: Size(140, 44)`.

Card-sized tappables use `AppAnimations.tapScale(onTap: …, child: …)` for 0.97 press feedback
rather than a bare `GestureDetector`.

## Loading · empty · error

Every async read handles three states, and loading is a **shimmer shaped like the content**:

```dart
grounds.when(
  // No shared EmptyView exists yet — ErrorView without onRetry is the house empty state.
  data: (list) => list.isEmpty
      ? const ErrorView(message: 'No grounds near you yet')
      : Column(children: list.map((g) => GroundCard(ground: g)).toList()),
  loading: () => const Column(children: [GroundCardShimmer(), GroundCardShimmer()]),
  error: (e, _) => ErrorView(
    message: 'Could not load grounds',
    onRetry: () => ref.invalidate(groundsProvider(filter)),
  ),
);
```

New card type → new `*Shimmer` in `widgets/shimmer_loader.dart`, built from `ShimmerBox` and
`Shimmer.fromColors(baseColor: colors.input, highlightColor: colors.border)`.

Never show `e.toString()`. The notifier already produced a human sentence.

## Sticky bottom bars, safe areas, keyboard

```dart
Scaffold(
  backgroundColor: colors.background,
  body: SafeArea(child: /* the single scrollable */),
  bottomNavigationBar: StickyBottomBar(     // adds MediaQuery.padding.bottom itself
    priceLabel: 'Total', price: '₹1,200',
    buttonText: 'Confirm booking',
    isLoading: _submitting,                  // ← doubles as the double-submit guard
    onPressed: _confirm,
  ),
)
```

- Pick **one** bottom-inset mechanism: `SafeArea` **or** manual `MediaQuery.padding.bottom`.
  Both on the same edge double-pads.
- A screen with a hero image that must bleed under the status bar skips `SafeArea` on top and
  pads its own header with `MediaQuery.of(context).padding.top + N`.
- Keep `resizeToAvoidBottomInset` at its default `true`, make forms scrollable, and never put
  the focused field under a fixed bottom bar. Test with the keyboard open.
- One scrollable per screen. Mixed fixed/scrolling layouts use `CustomScrollView` + slivers
  (`home_screen.dart` is the reference).

## Double-submit and actions that route away

```dart
Future<void> _confirm() async {
  if (_submitting) return;
  setState(() => _submitting = true);
  try {
    final booking = await ref.read(bookingsProvider.notifier).create(...);
    if (!mounted) return;
    context.pushReplacement('/booking-confirm', extra: booking);  // never push
  } catch (e) {
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
  }
}
```

- The flag disables the control (`onPressed: isLoading ? null : …`) **and** guards re-entry.
- Reset it in every failure path; don't reset it on success if the screen is being replaced.
- A wait the user can't see isn't feedback: OTP verify auto-fires on the last digit while the
  keyboard covers the CTA — show a full-screen/overlay loader there, keeping the button
  spinner purely as the double-submit guard.
- Razorpay: loader on **before** awaiting the callback, non-cancelable, resolves once,
  result reached with `pushReplacement`.

## Motion budget

| Effect                  | Use                                        | Duration       |
| ----------------------- | ------------------------------------------ | -------------- |
| `AppAnimations.tapScale`| card / tile press                          | 100ms          |
| `AnimatedContainer`     | selection state (`SlotTile`)               | 150ms          |
| `AppAnimations.slideUpFade` | screen entrance (fade + 8% rise)       | ~220ms easeOut |
| `AnimatedListItem`      | staggered list entrance                    | ≤ 220ms each   |

One entrance layer per screen — stacked fades multiply and read as "nothing, then a pop".
Content that arrives *after* the screen animates on the container that mounts with the data.
If motion suppression is ever added, **exclude looping progress indicators** (shimmers,
spinners, payment waits); freezing them makes the app read as hung.

## Accessibility

- `Semantics(label:, button: true)` around icon-only tappables; `semanticLabel` on meaningful
  icons; decorative glyphs get `ExcludeSemantics`.
- Never state-by-color alone — `SlotTile` (available/selected/booked) and `StatusBadge` must
  each read correctly in greyscale; pair the fill with a label or icon.
- No fixed heights that clip at 1.3× text scale; `Flexible` + `TextOverflow.ellipsis` instead.
- Black foregrounds on `AppColors.primary`/`accent` fills (as the theme sets) — never white.

## Done means

`flutter analyze` clean · no literal colors or `AppTheme.*` legacy statics in touched files ·
every tappable ≥ 44px · every async CTA disables while pending · loading/empty/error all seen ·
checked in **light and dark**, Pixel 7 and iPhone 14, keyboard open where there's a text field.
