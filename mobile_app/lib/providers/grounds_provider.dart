import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/ground_model.dart';
import '../models/sport_model.dart';
import '../models/slot_model.dart';
import '../models/ground_sport_model.dart';
import '../models/review_eligibility_model.dart';

// ── Sports ─────────────────────────────────────────────────────────────────

final sportsProvider = FutureProvider<List<SportModel>>((ref) async {
  final res = await ApiClient.getSports();
  final list = res['data'] as List<dynamic>? ?? [];
  return SportModel.listFromJson(list);
});

// ── Grounds list ────────────────────────────────────────────────────────────

class GroundFilter {
  final int? sportId;
  final String? city;
  final String? search;
  final int page;

  const GroundFilter({this.sportId, this.city, this.search, this.page = 1});

  @override
  bool operator ==(Object other) =>
      other is GroundFilter &&
      other.sportId == sportId &&
      other.city == city &&
      other.search == search &&
      other.page == page;

  @override
  int get hashCode => Object.hash(sportId, city, search, page);
}

final groundsProvider =
    FutureProvider.family<List<GroundModel>, GroundFilter>((ref, filter) async {
  final res = await ApiClient.getGrounds(
    sportId: filter.sportId,
    city: filter.city,
    search: filter.search,
    page: filter.page,
  );
  final list = res['data'] as List<dynamic>? ?? [];
  return GroundModel.listFromJson(list);
});

// ── Ground detail ──────────────────────────────────────────────────────────

final groundDetailProvider =
    FutureProvider.family<GroundModel, int>((ref, id) async {
  final res = await ApiClient.getGround(id);
  final data = res['data'] as Map<String, dynamic>? ?? res;
  return GroundModel.fromJson(data);
});

// ── Ground sports ──────────────────────────────────────────────────────────

final groundSportsProvider =
    FutureProvider.family<List<GroundSportModel>, int>((ref, groundId) async {
  final res = await ApiClient.getGroundSports(groundId);
  final list = res['data'] as List<dynamic>? ?? [];
  return GroundSportModel.listFromJson(list);
});

// ── Slots ──────────────────────────────────────────────────────────────────

class SlotQuery {
  final int groundSportId;
  final String date;

  const SlotQuery({required this.groundSportId, required this.date});

  @override
  bool operator ==(Object other) =>
      other is SlotQuery &&
      other.groundSportId == groundSportId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(groundSportId, date);
}

final slotsProvider =
    FutureProvider.family<List<SlotModel>, SlotQuery>((ref, query) async {
  final res = await ApiClient.getSlots(query.groundSportId, query.date);
  final list =
      res['data'] as List<dynamic>? ?? res['slots'] as List<dynamic>? ?? [];
  return SlotModel.listFromJson(list);
});

/// Whether the signed-in customer may review this ground.
///
/// Fails closed and silent: a signed-out user, an expired token or a server
/// error all resolve to "no form offered" rather than an error state. The gate
/// that matters is the server's; this only decides what to show.
final reviewEligibilityProvider =
    FutureProvider.family<ReviewEligibility, int>((ref, groundId) async {
  try {
    final res = await ApiClient.getReviewEligibility(groundId);
    final data = res['data'];
    if (data is! Map<String, dynamic>) return ReviewEligibility.unknown;
    return ReviewEligibility.fromJson(data);
  } catch (_) {
    return ReviewEligibility.unknown;
  }
});
