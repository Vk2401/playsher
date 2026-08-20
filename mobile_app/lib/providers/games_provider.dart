import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/game_model.dart';

final gamesProvider = FutureProvider<List<GameModel>>((ref) async {
  final res = await ApiClient.getGames();
  final list =
      res['data'] as List<dynamic>? ?? res['games'] as List<dynamic>? ?? [];
  return GameModel.listFromJson(list);
});

final gameDetailProvider =
    FutureProvider.family<GameModel, int>((ref, id) async {
  final res = await ApiClient.getGame(id);
  final data = res['data'] as Map<String, dynamic>? ??
      res['game'] as Map<String, dynamic>? ??
      res;
  return GameModel.fromJson(data);
});

final myGamesProvider = FutureProvider<List<GameModel>>((ref) async {
  final res = await ApiClient.getGames();
  final list =
      res['data'] as List<dynamic>? ?? res['games'] as List<dynamic>? ?? [];
  // Filter for games user has joined (backend should support this;
  // for now return all games as placeholder)
  return GameModel.listFromJson(list);
});
