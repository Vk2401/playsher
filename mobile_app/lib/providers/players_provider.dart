import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/game_model.dart';
import '../models/player_model.dart';

// ── Reads ─────────────────────────────────────────────────────────────────────

/// One player's public profile. Keyed by handle — a username or a numeric id,
/// because a client links by whichever it holds.
final playerProfileProvider =
    FutureProvider.family<PlayerProfile, String>((ref, handle) async {
  final res = await ApiClient.getPlayer(handle);
  return PlayerProfile.fromJson(res['data'] as Map<String, dynamic>);
});

/// People I have shared a game with — the invite sheet's default list.
final teammatesProvider = FutureProvider<List<PlayerCard>>((ref) async {
  final res = await ApiClient.getTeammates();
  return PlayerCard.listFromJson(res['data'] as List<dynamic>? ?? []);
});

/// Search results for one query.
///
/// Keyed by the query string, so an identical search is served from cache and
/// a debounced keystroke is a new key rather than a manual refetch.
final playerSearchProvider =
    FutureProvider.family<List<PlayerCard>, String>((ref, query) async {
  final q = query.trim();
  // The API refuses anything shorter, and asking would only earn a 400.
  if (q.length < 2) return const [];
  final res = await ApiClient.searchPlayers(q);
  return PlayerCard.listFromJson(res['data'] as List<dynamic>? ?? []);
});

/// The public games a player is in.
///
/// Private games are never in here — the API refuses to list one to anyone but
/// its host and its invitees, so a profile cannot become a way to discover
/// games you were not asked to.
final playerGamesProvider =
    FutureProvider.family<List<GameModel>, String>((ref, handle) async {
  final res = await ApiClient.getPlayerGames(handle);
  return GameModel.listFromJson(res['data'] as List<dynamic>? ?? []);
});

final followersProvider =
    FutureProvider.family<List<PlayerCard>, String>((ref, handle) async {
  final res = await ApiClient.getFollowers(handle);
  return PlayerCard.listFromJson(res['data'] as List<dynamic>? ?? []);
});

final followingProvider =
    FutureProvider.family<List<PlayerCard>, String>((ref, handle) async {
  final res = await ApiClient.getFollowing(handle);
  return PlayerCard.listFromJson(res['data'] as List<dynamic>? ?? []);
});

// ── Follow ────────────────────────────────────────────────────────────────────

/// Following and unfollowing.
///
/// The state is the set of players with a request in flight, keyed by id: a
/// follow button anywhere on screen binds its spinner and its disabled state to
/// its own id, so following one person in a list does not freeze the rest.
///
/// Both calls are idempotent server-side, which is what lets the button reflect
/// the tap immediately and reconcile with the answer rather than waiting.
class FollowActions extends StateNotifier<Set<int>> {
  FollowActions(this._ref) : super(const {});

  final Ref _ref;

  bool isBusy(int playerId) => state.contains(playerId);

  /// Returns the follower count the server reports afterwards.
  Future<int?> follow(int playerId) =>
      _run(playerId, () => ApiClient.followPlayer(playerId));

  Future<int?> unfollow(int playerId) =>
      _run(playerId, () => ApiClient.unfollowPlayer(playerId));

  Future<int?> toggle(int playerId, {required bool isFollowing}) =>
      isFollowing ? unfollow(playerId) : follow(playerId);

  Future<int?> _run(
    int playerId,
    Future<Map<String, dynamic>> Function() body,
  ) async {
    if (state.contains(playerId)) return null;
    state = {...state, playerId};
    try {
      final res = await body();
      final data = res['data'] as Map<String, dynamic>?;

      // Every list and profile that could be showing this relationship.
      _ref.invalidate(playerProfileProvider);
      _ref.invalidate(followersProvider);
      _ref.invalidate(followingProvider);
      _ref.invalidate(teammatesProvider);
      _ref.invalidate(playerSearchProvider);

      return data?['followers_count'] as int?;
    } finally {
      state = {...state}..remove(playerId);
    }
  }
}

final followActionsProvider =
    StateNotifierProvider<FollowActions, Set<int>>(FollowActions.new);
