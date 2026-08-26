import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/coach_model.dart';
import '../models/slot_model.dart';

/// What the coaching list is filtered by. A value type so Riverpod can key
/// the family on it — two screens asking for the same filter share one fetch.
@immutable
class CoachQuery {
  final String? search;
  final String? sportName;
  final String? city;
  final int? groundId;

  const CoachQuery({this.search, this.sportName, this.city, this.groundId});

  @override
  bool operator ==(Object other) =>
      other is CoachQuery &&
      other.search == search &&
      other.sportName == sportName &&
      other.city == city &&
      other.groundId == groundId;

  @override
  int get hashCode => Object.hash(search, sportName, city, groundId);
}

final coachesProvider =
    FutureProvider.family<List<CoachModel>, CoachQuery>((ref, query) async {
  final res = await ApiClient.getCoaches(
    search: query.search,
    sportName: query.sportName,
    city: query.city,
    groundId: query.groundId,
  );
  return CoachModel.listFromJson(res['data'] as List<dynamic>? ?? const []);
});

final coachDetailProvider =
    FutureProvider.family<CoachModel, int>((ref, id) async {
  final res = await ApiClient.getCoach(id);
  return CoachModel.fromJson(res['data'] as Map<String, dynamic>);
});

/// A coach and a day. Keyed as a pair so switching dates in the booking flow
/// re-fetches instead of showing yesterday's times.
@immutable
class CoachSlotQuery {
  final int coachId;
  final String date;

  const CoachSlotQuery({required this.coachId, required this.date});

  @override
  bool operator ==(Object other) =>
      other is CoachSlotQuery &&
      other.coachId == coachId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(coachId, date);
}

/// The coach's bookable blocks for one day.
///
/// [SlotModel] is reused rather than copied: a coach slot carries the same
/// id / date / start / end / availability the ground slots do, and reusing it
/// means [SlotTile] and its past-slot guard work here unchanged.
final coachSlotsProvider =
    FutureProvider.family<List<SlotModel>, CoachSlotQuery>((ref, query) async {
  final res = await ApiClient.getCoachSlots(query.coachId, query.date);
  return SlotModel.listFromJson(res['data'] as List<dynamic>? ?? const []);
});
