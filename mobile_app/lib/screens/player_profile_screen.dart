import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/player_model.dart';
import '../providers/players_provider.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_view.dart';
import '../widgets/game_card.dart';
import '../widgets/player_tile.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/sport_glyph.dart';

/// Another player's profile.
///
/// The screen exists to answer one question, and which question depends on how
/// you got here: *should I join their game?* if you tapped a host, or *should I
/// invite them to mine?* if you tapped a squad member. Both are answered by the
/// same things — how much they play, who else plays with them, and what is on
/// their calendar.
///
/// Reached by handle: a username from a shared link, or a numeric id from a
/// notification. The API resolves both.
class PlayerProfileScreen extends ConsumerStatefulWidget {
  final String handle;

  const PlayerProfileScreen({super.key, required this.handle});

  @override
  ConsumerState<PlayerProfileScreen> createState() =>
      _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen> {
  /// Held locally so the header moves the instant the follow settles, rather
  /// than waiting for the profile to refetch. Reconciled from the server's
  /// answer, never guessed.
  bool? _following;
  int? _followers;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(playerProfileProvider(widget.handle));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/games'),
        title: profile.maybeWhen(
          data: (p) => Text(p.handle, style: const TextStyle(fontSize: 16)),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      body: profile.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [SizedBox(height: 20), GameCardShimmer()]),
        ),
        error: (e, _) => ErrorView(
          message: apiErrorMessage(e, fallback: 'Could not load this player'),
          onRetry: () => ref.invalidate(playerProfileProvider(widget.handle)),
        ),
        data: (player) {
          final following = _following ?? player.isFollowing;
          final followers = _followers ?? player.followersCount;

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: colors.card,
            onRefresh: () async {
              setState(() {
                _following = null;
                _followers = null;
              });
              ref.invalidate(playerProfileProvider(widget.handle));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _Header(
                  player: player,
                  following: following,
                  followers: followers,
                  onFollowChanged: (nowFollowing, count) => setState(() {
                    _following = nowFollowing;
                    // The server's count is authoritative; the local nudge is
                    // only for the moment before it answers.
                    _followers = count ??
                        (followers + (nowFollowing ? 1 : -1)).clamp(0, 1 << 30);
                  }),
                ),
                const SizedBox(height: 22),
                _Stats(player: player, followers: followers),
                if (player.sports.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _Sports(sports: player.sports),
                ],
                const SizedBox(height: 26),
                _UpcomingGames(handle: widget.handle, player: player),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final PlayerProfile player;
  final bool following;
  final int followers;
  final void Function(bool nowFollowing, int? count) onFollowChanged;

  const _Header({
    required this.player,
    required this.following,
    required this.followers,
    required this.onFollowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlayerAvatar(
              name: player.name,
              avatar: player.avatar,
              initials: player.initials,
              size: 72,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    player.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.brandText,
                    ),
                  ),
                  if (player.followsYou && !player.isSelf) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.input,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Follows you',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (player.bio?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Text(
            player.bio!.trim(),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: colors.textSecondary,
            ),
          ),
        ],
        if (player.memberSinceLabel != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 14, color: colors.textSecondary),
              const SizedBox(width: 5),
              Text(
                player.memberSinceLabel!,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ],
        if (!player.isSelf) ...[
          const SizedBox(height: 16),
          FollowButton(
            playerId: player.id,
            isFollowing: following,
            expanded: true,
            onChanged: onFollowChanged,
          ),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  final PlayerProfile player;
  final int followers;

  const _Stats({required this.player, required this.followers});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final handle = player.username ?? '${player.id}';

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _Stat(
            value: '$followers',
            label: followers == 1 ? 'Follower' : 'Followers',
            onTap: () => context.push('/players/$handle/followers'),
          ),
          _Divider(),
          _Stat(
            value: '${player.followingCount}',
            label: 'Following',
            onTap: () => context.push('/players/$handle/following'),
          ),
          _Divider(),
          _Stat(value: '${player.gamesPlayed}', label: 'Played'),
          _Divider(),
          _Stat(value: '${player.gamesHosted}', label: 'Hosted'),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: context.colors.border,
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _Stat({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: Semantics(
        button: onTap != null,
        label: '$value $label',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            // 44px minimum, whatever the text scale does to the two lines.
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sports extends StatelessWidget {
  final List<PlayerSport> sports;

  const _Sports({required this.sports});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plays',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sports
              .map((s) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SportGlyph(name: s.name, imageUrl: s.image, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          s.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

/// Their open games — the reason you might have come here.
class _UpcomingGames extends ConsumerWidget {
  final String handle;
  final PlayerProfile player;

  const _UpcomingGames({required this.handle, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final games = ref.watch(playerGamesProvider(handle));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          player.isSelf ? 'Your games' : 'Their games',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        games.when(
          loading: () => const GameCardShimmer(),
          // A profile is still a profile without its games; a failed strip
          // should not take the whole screen down with it.
          error: (_, __) => Text(
            'Could not load games right now.',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          data: (list) => list.isEmpty
              ? Text(
                  player.isSelf
                      ? 'You have no public games on right now.'
                      : 'No public games on right now.',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                )
              : Column(
                  children: list
                      .map((g) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GameCard(
                              game: g,
                              onTap: () => context.push('/games/${g.id}'),
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}
