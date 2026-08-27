import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/game_filters.dart';
import '../models/game_model.dart';

// ── Discover ──────────────────────────────────────────────────────────────────

/// The Discover feed for one set of filters.
///
/// Keyed by [GameFilters], which is a value type — two identical filters share
/// one fetch, and changing a chip is a new key rather than a manual refetch.
final gamesProvider =
    FutureProvider.family<List<GameModel>, GameFilters>((ref, filters) async {
  final res = await ApiClient.getGames(query: filters.toQuery());
  final list = res['data'] as List<dynamic>? ?? [];
  return GameModel.listFromJson(list);
});

// ── One game ──────────────────────────────────────────────────────────────────

final gameDetailProvider =
    FutureProvider.family<GameModel, int>((ref, id) async {
  final res = await ApiClient.getGame(id);
  final data = res['data'] as Map<String, dynamic>? ??
      res['game'] as Map<String, dynamic>? ??
      res;
  return GameModel.fromJson(data);
});

// ── My games ──────────────────────────────────────────────────────────────────

/// Games I host and games I have joined, for one half of the timeline.
///
/// `GET /games/mine` returns both in one list, each row tagged `relation`, so
/// the tab does not have to reconcile two calls that paginate separately.
final myGamesProvider =
    FutureProvider.family<List<GameModel>, MyGamesScope>((ref, scope) async {
  final res = await ApiClient.getMyGames(scope: scope.query);
  final list = res['data'] as List<dynamic>? ?? [];
  return GameModel.listFromJson(list);
});

// ── Actions ───────────────────────────────────────────────────────────────────

/// Taking and giving back a seat.
///
/// A notifier rather than a bare call so the in-flight flag lives next to the
/// request: every CTA that joins, leaves or cancels binds `isBusy` to its
/// disabled state, which is the double-submit guard. Two taps on "Join" must
/// never become two requests — the second would come back 409 and read to the
/// player as the app losing their seat.
class GameActions extends StateNotifier<GameActionState> {
  GameActions(this._ref) : super(const GameActionState());

  final Ref _ref;

  /// Take a seat. Returns the game as the server now sees it.
  Future<GameModel> join(int gameId) => _run(gameId, () async {
        final res = await ApiClient.joinGame(gameId);
        final data = res['data'] as Map<String, dynamic>?;
        _invalidate(gameId);
        return data == null
            ? await _ref.read(gameDetailProvider(gameId).future)
            : GameModel.fromJson(data);
      });

  /// Give the seat back.
  Future<void> leave(int gameId) => _run(gameId, () async {
        await ApiClient.leaveGame(gameId);
        _invalidate(gameId);
      });

  /// Call off a game I host. The booking is untouched.
  Future<void> cancel(int gameId) => _run(gameId, () async {
        await ApiClient.cancelGame(gameId);
        _invalidate(gameId);
      });

  Future<T> _run<T>(int gameId, Future<T> Function() body) async {
    if (state.isBusy) {
      // Belt and braces: the CTA is already disabled, but a stray programmatic
      // call must not slip a second request past it either.
      throw StateError('A game action is already in flight.');
    }
    state = GameActionState(busyGameId: gameId);
    try {
      return await body();
    } finally {
      state = const GameActionState();
    }
  }

  /// Everything that could be showing this game's seat count.
  void _invalidate(int gameId) {
    _ref.invalidate(gameDetailProvider(gameId));
    _ref.invalidate(gamesProvider);
    _ref.invalidate(myGamesProvider);
  }
}

/// Which game, if any, has an action in flight.
class GameActionState {
  final int? busyGameId;

  const GameActionState({this.busyGameId});

  bool get isBusy => busyGameId != null;

  /// Is *this* game the one waiting? Cards in a list each ask for themselves,
  /// so one join does not spin every button on screen.
  bool isBusyFor(int gameId) => busyGameId == gameId;
}

final gameActionsProvider =
    StateNotifierProvider<GameActions, GameActionState>(GameActions.new);
