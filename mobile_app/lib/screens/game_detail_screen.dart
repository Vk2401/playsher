import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/games_provider.dart';
import '../widgets/participant_avatar.dart';
import '../widgets/stat_grid.dart';
import '../widgets/status_badge.dart';
import '../widgets/sticky_bottom_bar.dart';
import '../widgets/trust_badge.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loader.dart';

class GameDetailScreen extends ConsumerWidget {
  final String gameId;
  const GameDetailScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final gameAsync = ref.watch(gameDetailProvider(int.parse(gameId)));

    return Scaffold(
      backgroundColor: colors.background,
      body: gameAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: GroundCardShimmer(),
        ),
        error: (e, _) => ErrorView(
            message: apiErrorMessage(e, fallback: 'Could not load this game')),
        data: (game) => Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Hero image
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.3),
                            colors.background,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.sports_cricket,
                            size: 80,
                            color: AppColors.primary.withValues(alpha: 0.3)),
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
                        // Sport badge + title
                        Row(
                          children: [
                            if (game.sportName != null)
                              StatusBadge(
                                label: game.sportName!,
                                color: AppColors.accent.withValues(alpha: 0.15),
                                textColor: AppColors.accent,
                              ),
                            const SizedBox(width: 8),
                            if (game.skillLevel.isNotEmpty)
                              StatusBadge.gameLevel(game.skillLevel),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          game.gameName ??
                              '${game.sportName ?? 'Game'} at ${game.groundName ?? 'Ground'}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Stats grid
                        StatGrid(stats: [
                          StatItem(
                              label: 'Date',
                              value: game.date,
                              icon: Icons.calendar_today),
                          StatItem(
                              label: 'Time',
                              value: game.time,
                              icon: Icons.access_time),
                          StatItem(
                              label: 'Level',
                              value: game.skillLevel.isNotEmpty
                                  ? game.skillLevel
                                  : 'Open',
                              icon: Icons.emoji_events),
                        ]),
                        const SizedBox(height: 20),
                        // Venue
                        if (game.groundName != null) ...[
                          Text('Venue',
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(game.groundName!,
                                          style: TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w600)),
                                      if (game.groundAddress != null)
                                        Text(game.groundAddress!,
                                            style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // Participants
                        Text(
                            'Players (${game.currentPlayers}/${game.maxPlayers})',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ...game.participants
                                .map((p) => ParticipantAvatar(participant: p)),
                            ...List.generate(
                              game.spotsLeft.clamp(0, 6),
                              (_) => const ParticipantAvatar(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // About
                        if (game.description != null &&
                            game.description!.isNotEmpty) ...[
                          Text('About Match',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary)),
                          const SizedBox(height: 8),
                          Text(game.description!,
                              style: TextStyle(
                                  color: colors.textSecondary, height: 1.5)),
                          const SizedBox(height: 20),
                        ],
                        // Trust badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TrustBadge.verified(),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Sticky bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StickyBottomBar(
                price: game.formattedFee,
                priceLabel: 'Entry Fee',
                buttonText: game.isFull ? 'Game Full' : 'Join Match',
                onPressed: game.isFull
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Joined the game!')),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
