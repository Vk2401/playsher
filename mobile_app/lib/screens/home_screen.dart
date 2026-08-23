import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../core/geo.dart';
import '../models/ground_model.dart';
import '../models/sport_model.dart';
import '../providers/auth_provider.dart';
import '../providers/city_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/grounds_provider.dart';
import '../providers/location_provider.dart';
import '../providers/notifications_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/ground_card.dart';
import '../widgets/home_header.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sport_glyph.dart';
import '../widgets/error_view.dart';
import '../widgets/why_book_strip.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // A peeking viewport: the sliver of the next card is what tells the user the
  // row scrolls at all.
  final _pageCtrl = PageController(viewportFraction: 0.62);
  int? _selectedSportId;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  GroundFilter get _filter => GroundFilter(sportId: _selectedSportId);

  /// Nearest first when we know where the user is; grounds with no coordinates
  /// keep their server order at the end rather than being dropped.
  List<GroundModel> _byDistance(List<GroundModel> list, UserLocation me) {
    if (!me.hasFix) return list;

    final ranked = [...list];
    ranked.sort((a, b) {
      final da = Geo.distanceKm(
          fromLat: me.latitude,
          fromLng: me.longitude,
          toLat: a.latitude,
          toLng: a.longitude);
      final db = Geo.distanceKm(
          fromLat: me.latitude,
          fromLng: me.longitude,
          toLat: b.latitude,
          toLng: b.longitude);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final city = ref.watch(cityProvider);
    final sports = ref.watch(sportsProvider);
    final grounds = ref.watch(groundsProvider(_filter));
    final unread = ref.watch(unreadNotificationCountProvider);
    final me = ref.watch(userLocationProvider);
    // Watched, not read: the heart on a featured card has to repaint when the
    // toggle lands. The notifier below is what answers "is this one saved".
    ref.watch(favoritesProvider);
    final favorites = ref.read(favoritesProvider.notifier);

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(sportsProvider);
          ref.invalidate(groundsProvider(_filter));
          // Silent: a pull never triggers a permission dialog, it just picks
          // up a fresher fix for anyone who already said yes.
          ref.read(userLocationProvider.notifier).refresh();
          await ref.read(notificationsProvider.notifier).load();
        },
        child: CustomScrollView(
          slivers: [
            // ── Hero header ─────────────────────────────────────────────────
            // The backdrop is the first venue's own photo. Before the list
            // resolves the header is the gradient alone, which is why nothing
            // here waits on `grounds`.
            SliverToBoxAdapter(
              child: HomeHeader(
                greeting: _greeting(auth.user?.name),
                city: city ?? auth.user?.city ?? 'Set your city',
                resolvingCity: me.resolving,
                unreadCount: unread,
                initials: auth.user?.initials ?? '?',
                backdropUrl: grounds.valueOrNull
                    ?.map((g) => g.primaryImageUrl)
                    .firstWhere((url) => url != null, orElse: () => null),
              ),
            ),

            // ── Location nudge ───────────────────────────────────────────────
            // Only appears when we cannot compute distances. Granting from
            // here is what turns "Recommended" into "Nearest to you".
            if (me.needsPrompt)
              const SliverToBoxAdapter(child: _LocationNudge()),

            // ── Categories ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: sports.when(
                loading: () => const CategoryStripShimmer(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: ErrorView(
                    message:
                        apiErrorMessage(e, fallback: 'Could not load sports'),
                    onRetry: () => ref.invalidate(sportsProvider),
                  ),
                ),
                data: (list) => _CategoriesRow(
                  sports: list,
                  selected: _selectedSportId,
                  onSelect: (id) => setState(() => _selectedSportId = id),
                ),
              ),
            ),

            // The offer strip (widgets/promo_banner.dart) belongs here, and is
            // deliberately not mounted: the coupons endpoint is still a stub,
            // so the only thing it could advertise is hard-coded copy. Put it
            // back when there is a real coupon to name.

            // ── Featured carousel ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: grounds.when(
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0, 24, 0, 14),
                      child: SectionHeader(
                        title: 'Featured Venues',
                        leading: Text('\u{1F525}', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(
                      height: _carouselHeight(context),
                      // Mirrors the carousel's peeking viewport so the
                      // skeleton sits exactly where the card will.
                      child: const Row(
                        children: [
                          SizedBox(width: 20),
                          Expanded(child: FeaturedCardShimmer()),
                          SizedBox(width: 10),
                          Expanded(child: FeaturedCardShimmer()),
                          SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ],
                ),
                // The list below reports the same failure with a retry;
                // repeating it here would stack two error blocks.
                error: (_, __) => const SizedBox.shrink(),
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  final featured = _byDistance(list, me).take(5).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 24, 0, 14),
                        child: SectionHeader(
                          title: 'Featured Venues',
                          leading: const Text('\u{1F525}',
                              style: TextStyle(fontSize: 18)),
                          actionText: 'See all',
                          onAction: () => context.go('/venues'),
                        ),
                      ),
                      SizedBox(
                        // Sized off the current text scale so the card's
                        // content cannot be clipped when the user bumps
                        // font size in system settings.
                        height: _carouselHeight(context),
                        child: PageView.builder(
                          controller: _pageCtrl,
                          padEnds: false,
                          itemCount: featured.length,
                          itemBuilder: (_, i) => Padding(
                            padding:
                                EdgeInsets.fromLTRB(i == 0 ? 20 : 0, 0, 10, 0),
                            child: GroundCard(
                              ground: featured[i],
                              wide: true,
                              isFavorite: favorites.isFavorite(featured[i].id),
                              onFavoriteToggle: () =>
                                  favorites.toggle(featured[i].id),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: SmoothPageIndicator(
                          controller: _pageCtrl,
                          count: featured.length,
                          effect: ExpandingDotsEffect(
                            activeDotColor: AppColors.primary,
                            dotColor: colors.border,
                            dotHeight: 6,
                            dotWidth: 6,
                            expansionFactor: 3,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Nearest to you ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 26, 0, 14),
                child: SectionHeader(
                  title: me.hasFix ? 'Nearest to you' : 'Recommended for you',
                  leading: Icon(
                    me.hasFix ? Icons.my_location_rounded : Icons.explore_outlined,
                    size: 19,
                    color: colors.textPrimary,
                  ),
                  actionText: 'See all',
                  onAction: () => context.go('/venues'),
                ),
              ),
            ),

            // ── Grounds list ─────────────────────────────────────────────────
            grounds.when(
              loading: () =>
                  const SliverToBoxAdapter(child: ListShimmer(count: 2)),
              error: (e, _) => SliverToBoxAdapter(
                child: ErrorView(
                  message:
                      apiErrorMessage(e, fallback: 'Could not load grounds'),
                  onRetry: () => ref.invalidate(groundsProvider(_filter)),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _NoGrounds(
                      sportFiltered: _selectedSportId != null,
                      onClearFilter: () =>
                          setState(() => _selectedSportId = null),
                    ),
                  );
                }
                final ordered = _byDistance(list, me);
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      // The stagger sits on the list that mounts with the
                      // data, not on the screen root — an entrance played on
                      // an empty screen is an entrance nobody sees.
                      (_, i) => AnimatedListItem(
                        index: i,
                        delay: const Duration(milliseconds: 40),
                        duration: const Duration(milliseconds: 220),
                        slideOffset: 16,
                        child: GroundCard(
                          ground: ordered[i],
                          showBookAction: true,
                        ),
                      ),
                      childCount: ordered.length,
                    ),
                  ),
                );
              },
            ),

            // ── Why book with us ────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: WhyBookStrip(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The featured card is image-led, so it wants to stay near 4:3 on the
  /// phone widths we target, and grow with the text scale so the footer row
  /// never gets clipped.
  double _carouselHeight(BuildContext context) {
    final scale =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4).scale(1);
    return 202 * scale;
  }
}

String _greeting(String? name) {
  final hour = DateTime.now().hour;
  final part = hour < 12
      ? 'Good morning'
      : hour < 17
          ? 'Good afternoon'
          : 'Good evening';
  final first = (name ?? '').trim().split(' ').first;
  return first.isEmpty ? part : '$part, $first';
}

// ── Location nudge ──────────────────────────────────────────────────────────

/// Explains what location buys the user, and asks for it in one tap.
///
/// The prompt is deliberately here and not on start-up: a system dialog that
/// appears before the user has seen a single ground gets refused, and a
/// refusal on iOS is close to permanent.
class _LocationNudge extends ConsumerStatefulWidget {
  const _LocationNudge();

  @override
  ConsumerState<_LocationNudge> createState() => _LocationNudgeState();
}

class _LocationNudgeState extends ConsumerState<_LocationNudge> {
  bool _working = false;

  Future<void> _act(LocationPermissionState permission) async {
    if (_working) return;
    setState(() => _working = true);

    final notifier = ref.read(userLocationProvider.notifier);
    try {
      switch (permission) {
        case LocationPermissionState.deniedForever:
          await notifier.openAppSettings();
        case LocationPermissionState.serviceDisabled:
          await notifier.openLocationSettings();
        default:
          final granted = await notifier.requestPermission();
          if (!mounted) return;
          if (!granted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text(
                    'Location is still off. You can turn it on any time from the city name above.'),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
              ));
          }
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final permission = ref.watch(userLocationProvider).permission;

    final (String body, String action) = switch (permission) {
      LocationPermissionState.deniedForever => (
          'Location is blocked for Playsher. Turn it on in Settings to see distances.',
          'Settings',
        ),
      LocationPermissionState.serviceDisabled => (
          'Your device location is switched off, so we cannot measure distances.',
          'Turn on',
        ),
      _ => (
          'See how far each ground is, nearest first.',
          'Enable',
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.near_me_rounded,
                  size: 18, color: colors.brandText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grounds near you',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style:
                        TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: _working ? null : () => _act(permission),
                style: TextButton.styleFrom(
                  minimumSize: const Size(72, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _working
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary),
                      )
                    : Text(
                        action,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _NoGrounds extends StatelessWidget {
  final bool sportFiltered;
  final VoidCallback onClearFilter;

  const _NoGrounds({required this.sportFiltered, required this.onClearFilter});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: colors.textSecondary),
          const SizedBox(height: 12),
          Text(
            sportFiltered
                ? 'No grounds for this sport yet'
                : 'No grounds near you yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          if (sportFiltered) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onClearFilter,
              style: TextButton.styleFrom(minimumSize: const Size(140, 44)),
              child: const Text('Show all sports'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Categories row ──────────────────────────────────────────────────────────

class _CategoriesRow extends StatelessWidget {
  final List<SportModel> sports;
  final int? selected;
  final void Function(int?) onSelect;

  const _CategoriesRow({
    required this.sports,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final allItems = [null, ...sports.map((s) => s as SportModel?)];

    return SizedBox(
      height: 96 *
              MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.3)
                  .scale(1) +
          16,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        itemCount: allItems.length,
        itemBuilder: (_, i) {
          final sport = allItems[i];
          final isActive =
              sport == null ? selected == null : selected == sport.id;
          final label = sport?.name ?? 'All';

          return Semantics(
            label: label,
            button: true,
            selected: isActive,
            child: GestureDetector(
              onTap: () => onSelect(sport?.id),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 82,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  // A white tile in both states — the selection is carried by
                  // the ring and the disc behind the glyph, so the strip does
                  // not turn into five competing fills.
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? AppColors.primary : colors.border,
                    width: isActive ? 1.6 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      // "All" is the one tile with no sport to draw, so it
                      // gets the brand's own ball rather than a stray emoji.
                      child: sport == null
                          ? Icon(Icons.sports_soccer_rounded,
                              size: 27,
                              color: isActive
                                  ? colors.brandText
                                  : colors.textSecondary)
                          : SportGlyph(
                              name: sport.name, imageUrl: sport.image),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          // The brand blue is a fill, not an ink: as label
                          // text on the light theme it needs the ink variant.
                          color: isActive
                              ? colors.brandText
                              : colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
