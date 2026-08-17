import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/ground_model.dart';

class FavoritesNotifier extends StateNotifier<AsyncValue<List<GroundModel>>> {
  FavoritesNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
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
      state = AsyncValue.data(grounds);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggle(int groundId) async {
    final current = state.valueOrNull ?? [];
    final isFav = current.any((g) => g.id == groundId);

    // Optimistic update
    if (isFav) {
      state = AsyncValue.data(
          current.where((g) => g.id != groundId).toList());
    }

    try {
      if (isFav) {
        await ApiClient.removeFavorite(groundId);
      } else {
        await ApiClient.addFavorite(groundId);
      }
      // Reload to get fresh data
      await load();
    } catch (_) {
      // Revert on error
      state = AsyncValue.data(current);
    }
  }

  bool isFavorite(int groundId) {
    return state.valueOrNull?.any((g) => g.id == groundId) ?? false;
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, AsyncValue<List<GroundModel>>>(
  (ref) => FavoritesNotifier(),
);
