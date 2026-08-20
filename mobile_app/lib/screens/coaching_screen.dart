import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/coaches_provider.dart';
import '../widgets/coach_card.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';

class CoachingScreen extends ConsumerWidget {
  const CoachingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final coachesAsync = ref.watch(coachesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Coaches',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Train with the best in your area',
                      style:
                          TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                      Text('Search coaches\u2026',
                          style: TextStyle(
                              fontSize: 14, color: colors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            // Featured banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        Colors.transparent
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Free Trial Session',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                    fontSize: 14)),
                            Text('Book your first coaching session free!',
                                style: TextStyle(
                                    fontSize: 12, color: colors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Coaches list
            coachesAsync.when(
              loading: () => SliverToBoxAdapter(
                  child: ShimmerList(
                      count: 3, itemBuilder: () => const CoachCardShimmer())),
              error: (e, _) => SliverToBoxAdapter(
                  child: ErrorView(
                      message: apiErrorMessage(e,
                          fallback: 'Could not load coaches'),
                      onRetry: () => ref.invalidate(coachesProvider))),
              data: (coaches) {
                if (coaches.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('No coaches available yet.',
                            style: TextStyle(
                                color: colors.textSecondary, fontSize: 15)),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: coaches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => CoachCard(
                      coach: coaches[i],
                      onTap: () => context.push('/coaching/${coaches[i].id}'),
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
