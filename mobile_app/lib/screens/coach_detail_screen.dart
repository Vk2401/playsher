import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/coaches_provider.dart';
import '../widgets/stat_grid.dart';
import '../widgets/sticky_bottom_bar.dart';
import '../widgets/trust_badge.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';

class CoachDetailScreen extends ConsumerWidget {
  final String coachId;
  const CoachDetailScreen({super.key, required this.coachId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final coachAsync = ref.watch(coachDetailProvider(int.parse(coachId)));

    return Scaffold(
      backgroundColor: colors.background,
      body: coachAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: CoachCardShimmer(),
        ),
        error: (e, _) => ErrorView(
            message: apiErrorMessage(e, fallback: 'Could not load this coach')),
        data: (coach) => Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.2),
                            colors.background
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 60),
                            CircleAvatar(
                              radius: 50,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                coach.name.isNotEmpty
                                    ? coach.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('PRO COACH',
                                  style: TextStyle(
                                      color: AppColors.onPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(coach.name,
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary)),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 16, color: AppColors.star),
                              const SizedBox(width: 4),
                              Text(
                                  '${coach.rating.toStringAsFixed(1)} (${coach.reviewCount} reviews)',
                                  style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        StatGrid(stats: [
                          StatItem(
                              label: 'Experience',
                              value: coach.experienceLabel,
                              icon: Icons.work),
                          StatItem(
                              label: 'Rate',
                              value: coach.formattedRate,
                              icon: Icons.payments),
                          StatItem(
                              label: 'Sport',
                              value: coach.sportName ?? 'Multi',
                              icon: Icons.sports),
                        ]),
                        const SizedBox(height: 20),
                        // Expertise tags
                        if (coach.expertiseTags.isNotEmpty) ...[
                          Text('Expertise',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: coach.expertiseTags
                                .map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(tag,
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500)),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // About
                        if (coach.bio != null && coach.bio!.isNotEmpty) ...[
                          Text('About',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary)),
                          const SizedBox(height: 8),
                          Text(coach.bio!,
                              style: TextStyle(
                                  color: colors.textSecondary, height: 1.5)),
                          const SizedBox(height: 20),
                        ],
                        // Location
                        if (coach.location != null) ...[
                          Text('Location',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Text(coach.location!,
                                    style:
                                        TextStyle(color: colors.textPrimary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Trust badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TrustBadge.certified(),
                            TrustBadge.quality(),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StickyBottomBar(
                price: coach.formattedRate,
                priceLabel: 'Per Session',
                buttonText: 'Book Coach',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking request sent!')));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
