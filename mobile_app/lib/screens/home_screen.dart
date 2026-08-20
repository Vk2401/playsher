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
import '../providers/grounds_provider.dart';
import '../providers/location_provider.dart';
import '../providers/notifications_provider.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/ground_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sport_glyph.dart';
import '../widgets/error_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // A peeking viewport: the sliver of the next card is what tells the user the
  // row scrolls at all.
  final _pageCtrl = PageController(viewportFraction: 0.87);
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
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(auth.user?.name),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            _LocationChip(
                              label: city ?? auth.user?.city ?? 'Set your city',
                              resolving: me.resolving,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _NotificationBell(unread: unread),
                      const SizedBox(width: 4),
                      _ProfileAvatar(initials: auth.user?.initials ?? '?'),
                    ],
                  ),
                ),
              ),
            ),

            // ── Search Bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Semantics(
                  label: 'Search grounds and sports',
                  button: true,
                  child: GestureDetector(
                    onTap: () => context.go('/venues'),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
                      decoration: BoxDecoration(
                        color: colors.input,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: colors.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search grounds, sports…',
                              style: TextStyle(
                                  fontSize: 14, color: colors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.tune_rounded,
                                size: 18, color: colors.brandText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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

            // ── Featured carousel ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: grounds.when(
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0, 24, 0, 14),
                      child: SectionHeader(title: 'Featured'),
                    ),
                    SizedBox(
                      height: _carouselHeight(context),
                      // Mirrors the carousel's peeking viewport so the
                      // skeleton sits exactly where the card will.
                      child: const Row(
                        children: [
                          SizedBox(width: 20),
                          Expanded(child: FeaturedCardShimmer()),
                          SizedBox(width: 56),
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
                      const Padding(
                        padding: EdgeInsets.fromLTRB(0, 24, 0, 14),
                        child: SectionHeader(title: 'Featured'),
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
                            padding: EdgeInsets.fromLTRB(i == 0 ? 20 : 0, 0, 10, 0),
                            child: GroundCard(ground: featured[i], wide: true),
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

            // ── Recommended ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 28, 0, 14),
                child: SectionHeader(
                  title: me.hasFix ? 'Nearest to you' : 'Recommended for you',
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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
                        child: GroundCard(ground: ordered[i]),
                      ),
                      childCount: ordered.length,
                    ),
                  ),
                );
              },
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
    return 236 * scale;
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
  return first.isEmpty ? '$part \u{1F44B}' : '$part, $first';
}

// ── Header pieces ───────────────────────────────────────────────────────────

/// The city, as a control rather than a label — tapping it goes to the
/// location screen, which is the only way to change it.
class _LocationChip extends StatelessWidget {
  final String label;
  final bool resolving;

  const _LocationChip({required this.label, required this.resolving});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: 'Your location, $label. Change it.',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/location'),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              if (resolving)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.6, color: colors.textSecondary),
                )
              else
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unread;
  const _NotificationBell({required this.unread});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/notifications'),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const SizedBox(width: 44, height: 44),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.input,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.notifications_outlined,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
            if (unread > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.background, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: AppColors.onImage,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String initials;
  const _ProfileAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your profile',
      button: true,
      child: GestureDetector(
        onTap: () => context.go('/profile'),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.colors.brandText,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 40),
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

// ── Categories row ──────────────────────────────────────────────────────────────

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
                width: 80,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : colors.input,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? AppColors.primary : colors.border,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    sport == null
                        ? const ExcludeSemantics(
                            child: Text('\u{1F3C5}',
                                style: TextStyle(fontSize: 28)))
                        : SportGlyph(name: sport.name, imageUrl: sport.image),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          // The neon primary is a fill, not an ink: as label
                          // text on the light theme it washes out.
                          color: isActive
                              ? colors.brandText
                              : colors.textSecondary,
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
