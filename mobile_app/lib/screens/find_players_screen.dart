import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/player_model.dart';
import '../providers/players_provider.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_view.dart';
import '../widgets/player_search.dart';
import '../widgets/player_tile.dart';

/// Find players, and follow them.
///
/// Until this screen existed, searching for somebody was only possible from the
/// Invite button on a game you already hosted — so a player who had never
/// hosted could not find anyone at all, and following depended on stumbling
/// across a profile in a game's squad. The follow graph had no front door.
///
/// It opens on the people you have already played with, because those are the
/// only names the app can offer before anything is typed, and they are the ones
/// most worth following: you have stood on a pitch with them.
class FindPlayersScreen extends ConsumerStatefulWidget {
  const FindPlayersScreen({super.key});

  @override
  ConsumerState<FindPlayersScreen> createState() => _FindPlayersScreenState();
}

class _FindPlayersScreenState extends ConsumerState<FindPlayersScreen> {
  String _query = '';

  bool get _searching => _query.trim().length >= 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final results = _searching
        ? ref.watch(playerSearchProvider(_query))
        : ref.watch(teammatesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/profile'),
        title: const Text('Find players'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlayerSearchField(
                    onChanged: (q) => setState(() => _query = q),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Search by username, name, or their full mobile number.',
                    style:
                        TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: PlayerListLabel(
                _searching ? 'Results' : 'People you play with',
              ),
            ),
            Expanded(
              child: results.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message:
                      apiErrorMessage(e, fallback: 'Could not load players'),
                  onRetry: () => ref.invalidate(_searching
                      ? playerSearchProvider(_query)
                      : teammatesProvider),
                ),
                data: (players) => players.isEmpty
                    ? ListView(
                        // Scrollable so the empty copy can still be pulled at
                        // and so the keyboard can be dismissed by dragging.
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          PlayerSearchEmpty(
                            searching: _searching,
                            query: _query,
                            idleTitle: 'No teammates yet',
                            idleBody:
                                'Once you have played a game together, your '
                                'teammates show up here — ready to follow. '
                                'Until then, search for them above.',
                          ),
                          if (!_searching) const _FindGamesNudge(),
                        ],
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: colors.card,
                        onRefresh: () async => ref.invalidate(_searching
                            ? playerSearchProvider(_query)
                            : teammatesProvider),
                        child: ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: players.length,
                          itemBuilder: (_, i) => _Row(player: players[i]),
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

class _Row extends StatelessWidget {
  final PlayerCard player;

  const _Row({required this.player});

  @override
  Widget build(BuildContext context) => PlayerTile(
        player: player,
        onTap: () => context.push('/players/${player.username ?? player.id}'),
        trailing: FollowButton(
          playerId: player.id,
          isFollowing: player.isFollowing,
          isSelf: player.isSelf,
        ),
      );
}

/// A way out of the empty state that is not "type something".
///
/// Somebody with no teammates cannot search their way to a first one — they do
/// not know anybody's handle yet. The thing that actually fixes it is joining a
/// game, so the screen says so rather than leaving them at a dead end.
class _FindGamesNudge extends StatelessWidget {
  const _FindGamesNudge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      child: Center(
        child: SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/games'),
            icon: const Icon(Icons.sports_soccer_rounded, size: 18),
            label: const Text('Find a game to join'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(220, 52)),
          ),
        ),
      ),
    );
  }
}
