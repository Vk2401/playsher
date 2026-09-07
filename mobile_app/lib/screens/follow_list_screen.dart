import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/players_provider.dart';
import '../widgets/app_back_button.dart';
import '../widgets/error_view.dart';
import '../widgets/player_tile.dart';

/// Who follows a player, or who they follow.
///
/// One screen for both, because they are the same list with a different fixed
/// end — and building them separately is how the two drift apart.
class FollowListScreen extends ConsumerWidget {
  final String handle;
  final bool followers;

  const FollowListScreen({
    super.key,
    required this.handle,
    required this.followers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final provider =
        followers ? followersProvider(handle) : followingProvider(handle);
    final people = ref.watch(provider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: AppBackButton(fallbackRoute: '/players/$handle'),
        title: Text(followers ? 'Followers' : 'Following'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: colors.card,
        onRefresh: () async => ref.invalidate(provider),
        child: people.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            message: apiErrorMessage(e, fallback: 'Could not load this list'),
            onRetry: () => ref.invalidate(provider),
          ),
          data: (list) {
            if (list.isEmpty) {
              // "You follow nobody" is the one empty state with an obvious
              // next step, so it offers it rather than just stating the fact.
              //
              // Answered from the signed-in account rather than by reading the
              // profile provider: the handle in the path is either my username
              // or my id, and asking the account costs nothing where fetching a
              // profile just to decide a button would.
              final me = ref.watch(authProvider).user;
              final mine = me != null &&
                  (handle == me.username || handle == '${me.id}');
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
                  ErrorView(
                    message: followers
                        ? (mine
                            ? 'Nobody follows you yet.'
                            : 'Nobody follows this player yet.')
                        : (mine
                            ? 'You are not following anyone yet.'
                            : 'This player does not follow anyone yet.'),
                  ),
                  if (mine && !followers)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/players'),
                            icon: const Icon(Icons.person_search_rounded,
                                size: 18),
                            label: const Text('Find players'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(200, 52),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                return PlayerTile(
                  player: p,
                  onTap: () =>
                      context.push('/players/${p.username ?? p.id}'),
                  trailing: FollowButton(
                    playerId: p.id,
                    isFollowing: p.isFollowing,
                    isSelf: p.isSelf,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
