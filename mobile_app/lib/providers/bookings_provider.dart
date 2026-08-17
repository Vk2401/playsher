import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/booking_model.dart';

final bookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final res  = await ApiClient.getBookings();
  final list = res['data'] as List<dynamic>?
            ?? res['bookings'] as List<dynamic>?
            ?? [];
  return BookingModel.listFromJson(list);
});

final bookingDetailProvider =
    FutureProvider.family<BookingModel, int>((ref, id) async {
  final res  = await ApiClient.getBooking(id);
  final data = res['data'] as Map<String, dynamic>? ?? res;
  return BookingModel.fromJson(data);
});
