import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../models/sport_model.dart';
import '../providers/auth_provider.dart';
import '../providers/city_provider.dart';
import '../providers/grounds_provider.dart';
import '../providers/notifications_provider.dart';
import '../widgets/ground_card.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/error_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pageCtrl = PageController();
  int? _selectedSportId;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final city = ref.watch(cityProvider);
    final sports = ref.watch(sportsProvider);
    final grounds = ref.watch(
        groundsProvider(GroundFilter(sportId: _selectedSportId)));
    final unread = ref.watch(notificationsProvider
        .select((list) => list.where((n) => !n.isRead).length));

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: colors.card,
        onRefresh: () async {
          ref.invalidate(sportsProvider);
          ref.invalidate(
              groundsProvider(GroundFilter(sportId: _selectedSportId)));
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 13, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text(
                                  city ?? auth.user?.city ?? 'Near You',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          // Notification bell
                          GestureDetector(
                            onTap: () => context.push('/notifications'),
                            child: Stack(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: colors.input,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: colors.border),
                                  ),
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    size: 20,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(
                                            color: Colors.white,
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
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  auth.user?.initials ?? '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Search Bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GestureDetector(
                  onTap: () => context.go('/venues'),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.input,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded,
                            color: colors.textSecondary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Search grounds, sports\u2026',
                          style: TextStyle(
                              fontSize: 14, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Categories ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: sports.when(
                loading: () => const SizedBox(height: 112),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => _CategoriesRow(
                  sports: list,
                  selected: _selectedSportId,
                  onSelect: (id) =>
                      setState(() => _selectedSportId = id),
                ),
              ),
            ),

            // ── Featured carousel ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: grounds.when(
                loading: () => const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: GroundCardShimmer(),
                ),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  final featured = list.take(5).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 24, 20, 14),
                        child: Text(
                          'Featured',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 280,
                        child: PageView.builder(
                          controller: _pageCtrl,
                          padEnds: false,
                          itemCount: featured.length,
                          itemBuilder: (_, i) => Padding(
                            padding:
                                EdgeInsets.only(left: i == 0 ? 20 : 0),
                            child: GroundCard(
                                ground: featured[i], wide: true),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                  title: 'Recommended for you',
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
                  child: ErrorView(message: e.toString())),
              data: (list) {
                if (list.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No grounds found',
                          style:
                              TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => GroundCard(ground: list[i]),
                      childCount: list.length,
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

  static const _emojis = {
    'cricket': '\ud83c\udfd0',
    'football': '\u26bd',
    'basketball': '\ud83c\udfc0',
    'volleyball': '\ud83c\udfd0',
    'badminton': '\ud83c\udff8',
    'tennis': '\ud83c\udfbe',
    'hockey': '\ud83c\udfd1',
    'kabaddi': '\ud83e\udd3c',
    'swimming': '\ud83c\udfca',
    'gym': '\ud83d\udcaa',
  };

  String _emojiFor(String name) {
    final lower = name.toLowerCase();
    for (final e in _emojis.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return '\ud83c\udfc6';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final allItems = [null, ...sports.map((s) => s as SportModel?)];

    return SizedBox(
      height: 112,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        itemCount: allItems.length,
        itemBuilder: (_, i) {
          final sport = allItems[i];
          final isActive =
              sport == null ? selected == null : selected == sport.id;
          final label = sport?.name ?? 'All';
          final emoji = sport != null ? _emojiFor(sport.name) : '\ud83c\udfc5';

          return GestureDetector(
            onTap: () => onSelect(sport?.id),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : colors.input,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? AppColors.primary : colors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.primary
                          : colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
