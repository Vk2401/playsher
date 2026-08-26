import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/coach_booking_model.dart';

/// The customer's coaching sessions.
final coachBookingsProvider =
    FutureProvider<List<CoachBookingModel>>((ref) async {
  final res = await ApiClient.getCoachBookings();
  return CoachBookingModel.listFromJson(
      res['data'] as List<dynamic>? ?? const []);
});

final coachBookingDetailProvider =
    FutureProvider.family<CoachBookingModel, int>((ref, id) async {
  final res = await ApiClient.getCoachBooking(id);
  return CoachBookingModel.fromJson(res['data'] as Map<String, dynamic>);
});

/// Booking a coach, and cancelling one.
///
/// The notifier owns `isLoading` so the CTA can bind its disabled state to the
/// same flag that the request sets and clears — a local bool in the screen is
/// what gets forgotten in a `catch` and leaves a button dead.
class CoachBookingNotifier extends StateNotifier<CoachBookingState> {
  CoachBookingNotifier(this._ref) : super(const CoachBookingState());

  final Ref _ref;

  Future<CoachBookingModel?> book({
    required int coachId,
    required String sessionDate,
    required List<int> slotIds,
    int? groundId,
    String? customerNote,
  }) async {
    state = const CoachBookingState(isLoading: true);
    try {
      final res = await ApiClient.createCoachBooking(
        coachId: coachId,
        sessionDate: sessionDate,
        slotIds: slotIds,
        groundId: groundId,
        customerNote: customerNote,
      );
      final booking =
          CoachBookingModel.fromJson(res['data'] as Map<String, dynamic>);
      state = const CoachBookingState();
      _ref.invalidate(coachBookingsProvider);
      return booking;
    } catch (e) {
      state = CoachBookingState(
        error: apiErrorMessage(e, fallback: 'Could not book this session'),
      );
      return null;
    }
  }

  Future<bool> cancel(int id, {String? reason}) async {
    state = const CoachBookingState(isLoading: true);
    try {
      await ApiClient.cancelCoachBooking(id, reason: reason);
      state = const CoachBookingState();
      _ref.invalidate(coachBookingsProvider);
      _ref.invalidate(coachBookingDetailProvider(id));
      return true;
    } catch (e) {
      state = CoachBookingState(
        error: apiErrorMessage(e, fallback: 'Could not cancel this session'),
      );
      return false;
    }
  }

  void clearError() => state = CoachBookingState(isLoading: state.isLoading);
}

class CoachBookingState {
  final bool isLoading;
  final String? error;

  const CoachBookingState({this.isLoading = false, this.error});
}

final coachBookingNotifierProvider =
    StateNotifierProvider<CoachBookingNotifier, CoachBookingState>(
  (ref) => CoachBookingNotifier(ref),
);
