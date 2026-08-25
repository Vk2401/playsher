import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/coach_model.dart';
import '../providers/coaches_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/stat_grid.dart';
import '../widgets/sticky_bottom_bar.dart';
import '../widgets/trust_badge.dart';

class CoachDetailScreen extends ConsumerWidget {
  final String coachId;
  const CoachDetailScreen({super.key, required this.coachId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final id = int.tryParse(coachId);
    if (id == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const ErrorView(message: 'That coach link is not valid'),
      );
    }

    final coachAsync = ref.watch(coachDetailProvider(id));

    return Scaffold(
      backgroundColor: colors.background,
      body: coachAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: CoachCardShimmer(),
        ),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e, fallback: 'Could not load this coach'),
          onRetry: () => ref.invalidate(coachDetailProvider(id)),
        ),
        data: (coach) => _Body(coach: coach),
      ),
      // The CTA belongs to the Scaffold, not to a Positioned inside the body:
      // there it scrolled with the content on short pages and sat under the
      // home indicator on gesture-navigation phones.
      bottomNavigationBar: coachAsync.maybeWhen(
        data: (coach) => StickyBottomBar(
          price: coach.formattedRate,
          priceLabel: coach.isBookable ? 'Per 30 min' : null,
          priceCaption: coach.isBookable ? coach.formattedHourlyRate : null,
          buttonText: coach.isBookable ? 'Book Coach' : 'Not bookable yet',
          onPressed: coach.isBookable
              ? () => context.push('/coaching/${coach.id}/book')
              : null,
        ),
        orElse: () => null,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final CoachModel coach;
  const _Body({required this.coach});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CustomScrollView(
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
                    _Avatar(coach: coach),
                    const SizedBox(height: 8),
                    if (coach.level != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(coach.level!.toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.onAccent,
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
                          coach.reviewCount == 0
                              ? 'No reviews yet'
                              : '${coach.rating.toStringAsFixed(1)} (${coach.reviewCount} reviews)',
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 13)),
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
                      value: coach.isBookable
                          ? coach.formattedHourlyRate
                          : 'On request',
                      icon: Icons.payments),
                  StatItem(
                      label: 'Sport',
                      value: coach.sportName ?? 'Multi',
                      icon: Icons.sports),
                ]),
                const SizedBox(height: 20),

                // Where this coach can actually be booked. Only grounds whose
                // owner approved them appear — that approval is what makes a
                // venue selectable in the booking flow.
                _Section(
                  title: 'Trains at',
                  child: coach.venues.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 18, color: colors.textSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No venue yet — you can still book this coach '
                                  'and agree a place together.',
                                  style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            for (final venue in coach.venues)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(venue.name,
                                                style: TextStyle(
                                                    color: colors.textPrimary,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            if (venue.locality.isNotEmpty)
                                              Text(venue.locality,
                                                  style: TextStyle(
                                                      color:
                                                          colors.textSecondary,
                                                      fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),

                if (coach.expertiseTags.isNotEmpty)
                  _Section(
                    title: 'Expertise',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: coach.expertiseTags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
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
                  ),

                if (coach.about != null && coach.about!.isNotEmpty)
                  _Section(
                    title: 'About',
                    child: Text(coach.about!,
                        style: TextStyle(
                            color: colors.textSecondary, height: 1.5)),
                  ),

                if (coach.experienceDetails != null &&
                    coach.experienceDetails!.isNotEmpty)
                  _Section(
                    title: 'Experience',
                    child: Text(coach.experienceDetails!,
                        style: TextStyle(
                            color: colors.textSecondary, height: 1.5)),
                  ),

                if (coach.awards != null && coach.awards!.isNotEmpty)
                  _Section(
                    title: 'Awards',
                    child: Text(coach.awards!,
                        style: TextStyle(
                            color: colors.textSecondary, height: 1.5)),
                  ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TrustBadge.certified(),
                    TrustBadge.quality(),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final CoachModel coach;
  const _Avatar({required this.coach});

  @override
  Widget build(BuildContext context) {
    final initial = coach.name.isNotEmpty ? coach.name[0].toUpperCase() : '?';
    final fallback = CircleAvatar(
      radius: 50,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(initial,
          style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.primary)),
    );

    final photo = coach.photo;
    if (photo == null || photo.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photo,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 20),
      ],
    );
  }
}
