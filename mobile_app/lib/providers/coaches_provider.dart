import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/coach_model.dart';

final coachesProvider = FutureProvider<List<CoachModel>>((ref) async {
  final res = await ApiClient.getCoaches();
  final list =
      res['data'] as List<dynamic>? ?? res['coaches'] as List<dynamic>? ?? [];
  return CoachModel.listFromJson(list);
});

final coachDetailProvider =
    FutureProvider.family<CoachModel, int>((ref, id) async {
  final res = await ApiClient.getCoach(id);
  final data = res['data'] as Map<String, dynamic>? ??
      res['coach'] as Map<String, dynamic>? ??
      res;
  return CoachModel.fromJson(data);
});
