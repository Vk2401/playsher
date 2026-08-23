import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/ground_model.dart';

/// The grounds the signed-in user has saved.
///
/// The heart on a card is the feedback for tapping the heart on a card, so
/// this notifier flips it first and tells the server afterwards. It used to do
/// the opposite: a tap waited a round trip for the write, then a *second* one
/// for a full reload that cleared the list to `loading` on the way — so the
/// heart sat unfilled for both, and briefly went back to unfilled in between.
/// That is the "nothing happened, then it happened twice" a slow save reads as.
class FavoritesNotifier extends StateNotifier<AsyncValue<List<GroundModel>>> {
  FavoritesNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  /// Grounds with a write already in flight.
  ///
  /// A second tap on the same heart before the first answers would race two
  /// opposite writes and leave the server disagreeing with the card, so it is
  /// dropped — the card is already showing the state that tap would ask for.
  final _inFlight = <int>{};

  /// Reads the list from the server.
  ///
  /// [silent] keeps whatever is on screen while the request runs, for the
  /// refresh that follows a toggle: clearing to `loading` there is what made
  /// a just-filled heart blink back to empty.
  Future<void> load({bool silent = false}) async {
    if (!silent) state = const AsyncValue.loading();
    try {
      final res = await ApiClient.getFavorites();
      final list = res['data'] as List<dynamic>? ??
          res['favorites'] as List<dynamic>? ??
          [];
      // Each favorite may wrap the ground inside a 'ground' key
      final grounds = list.map((e) {
        final map = e as Map<String, dynamic>;
        final ground = map['ground'] as Map<String, dynamic>? ?? map;
        return GroundModel.fromJson(ground);
      }).toList();
      // Disposed on logout, and this request may well outlive that.
      if (!mounted) return;
      state = AsyncValue.data(grounds);
    } catch (e, st) {
      if (!mounted) return;
      // A background refresh that fails must not wipe a list the user is
      // looking at; the next load will pick it up.
      if (silent && state.hasValue) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// Saves or unsaves [ground], on screen immediately.
  ///
  /// Takes the whole model rather than an id because an optimistic *add* has
  /// to put something in the list, and the card tapping it already holds it.
  Future<void> toggle(GroundModel ground) async {
    if (_inFlight.contains(ground.id)) return;

    final current = state.valueOrNull ?? const <GroundModel>[];
    final wasSaved = current.any((g) => g.id == ground.id);

    state = AsyncValue.data(wasSaved
        ? [
            for (final g in current)
              if (g.id != ground.id) g,
          ]
        : [...current, ground]);

    _inFlight.add(ground.id);
    try {
      if (wasSaved) {
        await ApiClient.removeFavorite(ground.id);
      } else {
        await ApiClient.addFavorite(ground.id);
      }
      // Reconcile with the server without disturbing what is on screen.
      await load(silent: true);
    } catch (_) {
      // Put it back: the heart showed a save that did not happen.
      if (!mounted) return;
      state = AsyncValue.data(current);
    } finally {
      _inFlight.remove(ground.id);
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, AsyncValue<List<GroundModel>>>(
  (ref) => FavoritesNotifier(),
);

/// Just the saved ids.
///
/// What a card actually needs to draw its heart, and cheaper to compare than
/// the list: a card rebuilds when this set changes, not every time any field
/// of any saved ground does.
final favoriteIdsProvider = Provider<Set<int>>((ref) {
  final saved = ref.watch(favoritesProvider).valueOrNull;
  return {for (final ground in saved ?? const <GroundModel>[]) ground.id};
});
