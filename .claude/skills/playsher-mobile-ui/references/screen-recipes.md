# Screen recipes — Playsher Flutter

Copy-paste scaffolds that already satisfy `docs/mobile-ui-guidelines.md`.

## 1. List screen (tab root, pull-to-refresh, slivers)

Reference: `lib/screens/home_screen.dart`.

```dart
class VenuesScreen extends ConsumerStatefulWidget {
  const VenuesScreen({super.key});
  @override
  ConsumerState<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends ConsumerState<VenuesScreen> {
  int? _sportId;

  @override
  Widget build(BuildContext context) {
    final colors  = context.colors;
    final filter  = GroundFilter(sportId: _sportId);
    final grounds = ref.watch(groundsProvider(filter));

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: colors.card,
        onRefresh: () async => ref.invalidate(groundsProvider(filter)),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: SectionHeader(title: 'Venues near you'),
                ),
              ),
            ),
            grounds.when(
              data: (list) => list.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorView(message: 'No venues here yet'))
                  : SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => AnimatedListItem(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GroundCard(ground: list[i]),
                        ),
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [GroundCardShimmer(), GroundCardShimmer()]),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  message: 'Could not load venues',
                  onRetry: () => ref.invalidate(groundsProvider(filter)),
                ),
              ),
            ),
            // Clears the bottom NavigationBar + home indicator.
            SliverToBoxAdapter(
              child: SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
            ),
          ],
        ),
      ),
    );
  }
}
```

Notes:
- `SafeArea(bottom: false)` on the header — the bottom inset is handled once, by the trailing
  spacer. Never both.
- The empty and error branches must fill remaining height, or `RefreshIndicator` has nothing
  to pull.

## 2. Detail screen with a sticky CTA

Reference: `lib/screens/ground_detail_screen.dart`, `booking_flow_screen.dart`.

```dart
Scaffold(
  backgroundColor: colors.background,
  body: detail.when(
    data: (g) => CustomScrollView(slivers: [
      SliverAppBar(                        // hero image bleeds under the status bar
        expandedHeight: 280,
        pinned: true,
        backgroundColor: colors.background,
        flexibleSpace: FlexibleSpaceBar(background: _Gallery(images: g.images)),
      ),
      SliverToBoxAdapter(child: _Body(ground: g)),
      SliverToBoxAdapter(child: SizedBox(height: 24)),   // bottom inset is the bar's job
    ]),
    loading: () => const ListShimmer(),      // or add a GroundDetailShimmer to shimmer_loader.dart
    error: (e, _) => ErrorView(
      message: 'Could not load this venue',
      onRetry: () => ref.invalidate(groundDetailProvider(id)),
    ),
  ),
  bottomNavigationBar: detail.maybeWhen(
    data: (g) => StickyBottomBar(
      priceLabel: 'Starting from',
      price: g.formattedStartingPrice,
      buttonText: 'Book now',
      onPressed: () => context.push('/book/${g.id}'),
    ),
    orElse: () => null,          // no CTA until the data that fills it exists
  ),
)
```

Do **not** put the CTA inside the scroll body — it scrolls away, which is the "whole page
scrolls" bug. `StickyBottomBar` already adds `MediaQuery.padding.bottom`.

## 3. Form screen (keyboard-safe)

Reference: `lib/screens/register_screen.dart`, `phone_screen.dart`.

```dart
Scaffold(
  backgroundColor: colors.background,
  // resizeToAvoidBottomInset stays true (default) — the keyboard must shrink the viewport.
  body: SafeArea(
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Continue'),
            ),
          ),
        ],
      ),
    ),
  ),
)
```

The submit button is inside the scrollable so the keyboard can never bury it. If the design
demands a pinned CTA on a form screen, the field must scroll *above* it — verify with the
keyboard open before calling it done.

## 4. Filter / selection sheet

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,                     // required or tall content is clipped
  backgroundColor: Colors.transparent,          // the theme's sheet shape draws the surface
  builder: (_) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: const _FilterSheet(),                // ends with a 52px apply button
  ),
);
```

`viewInsets.bottom` lifts the sheet above the keyboard; the theme's `bottomSheetTheme` already
supplies the 24px top radius and `colors.card` background.

## 5. Empty state

Until a shared `EmptyView` exists, `ErrorView` without `onRetry` is the house empty state — it
renders a centred icon + sentence. When you need a distinct icon/copy for empties, add
`EmptyView` to `lib/widgets/` (same layout, `Icons.search_off_rounded`, optional action button)
and use it everywhere instead of copying a `Column` into a screen.
