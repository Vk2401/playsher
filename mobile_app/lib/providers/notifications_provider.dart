import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/notification_model.dart';

/// Notifications, read from the API.
///
/// This used to serve a hardcoded list of four invented notifications, which
/// meant the home-screen bell showed a permanent unread badge of 2 and the
/// screen showed booking confirmations for grounds the user had never visited.
/// It now reflects whatever `GET /notifications` returns.
///
/// Note: the backend does not expose that route yet — `ApiClient.getNotifications`
/// answers with an empty list — so the screen legitimately shows its empty
/// state until the endpoint lands. That is the correct behaviour; inventing
/// rows to fill the space is not.
class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final res = await ApiClient.getNotifications();
      final list = res['data'] as List<dynamic>? ?? [];
      if (!mounted) return;
      state = AsyncValue.data(NotificationModel.listFromJson(list));
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// Optimistically flips the row, then tells the server. On failure the
  /// local state is reloaded so the UI never diverges from the backend.
  Future<void> markAsRead(int id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data([
      for (final n in current)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ]);

    try {
      await ApiClient.markNotificationRead(id);
    } catch (_) {
      await load();
    }
  }

  Future<void> markAllAsRead() async {
    final current = state.valueOrNull;
    if (current == null) return;

    state =
        AsyncValue.data(current.map((n) => n.copyWith(isRead: true)).toList());

    try {
      await ApiClient.markAllNotificationsRead();
    } catch (_) {
      await load();
    }
  }

  void remove(int id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.where((n) => n.id != id).toList());
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier,
    AsyncValue<List<NotificationModel>>>(
  (ref) => NotificationsNotifier(),
);

/// Unread count for the home-screen bell. Resolves to 0 while loading or on
/// error, so a failed fetch never paints a phantom badge.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.valueOrNull?.where((n) => !n.isRead).length ?? 0;
});
