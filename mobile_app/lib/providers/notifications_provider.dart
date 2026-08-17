import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

/// Local mock notifications (no backend endpoint yet).
class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier() : super(_mockNotifications);

  void markAsRead(int id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void remove(int id) {
    state = state.where((n) => n.id != id).toList();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
  (ref) => NotificationsNotifier(),
);

final _mockNotifications = [
  NotificationModel(
    id: 1,
    title: 'Booking Confirmed',
    message: 'Your booking at Green Valley Ground has been confirmed for tomorrow.',
    type: 'booking',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  NotificationModel(
    id: 2,
    title: 'Game Starting Soon',
    message: 'Your cricket match starts in 2 hours. Don\'t forget your gear!',
    type: 'game',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  NotificationModel(
    id: 3,
    title: 'New Venue Near You',
    message: 'Sunrise Sports Arena just opened near your area. Check it out!',
    type: 'promo',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  NotificationModel(
    id: 4,
    title: 'Payment Received',
    message: 'Your payment of \u20b9500 has been processed successfully.',
    type: 'payment',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];
