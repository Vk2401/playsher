import 'package:flutter/widgets.dart';
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
/// **It also has to keep reflecting it.** The list was fetched exactly once,
/// when the provider was first built, and never again — so a notification that
/// arrived afterwards (somebody followed you, a booking confirmed) did not
/// reach the bell until the app was killed and reopened. Since there is no push
/// channel yet (FCM is Phase 2), the only thing that can notice a new
/// notification is the app asking again, which it now does on every resume and
/// every time the inbox is opened.
class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationsNotifier() : super(const AsyncValue.loading()) {
    // Coming back from the background is the moment most new notifications are
    // waiting: the phone was locked while someone followed you or your booking
    // confirmed.
    _lifecycle = AppLifecycleListener(onResume: refresh);
    load();
  }

  late final AppLifecycleListener _lifecycle;

  /// One request at a time. Opening the inbox on a resume fires both paths at
  /// once, and the slower answer would otherwise overwrite the fresher one.
  bool _inFlight = false;

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// The first read, or one after a failure: there is nothing on screen worth
  /// protecting, so a skeleton is the honest state.
  Future<void> load() => _fetch(showLoading: true);

  /// A re-read behind an existing list. Keeps what is already shown — a
  /// resume must never blank the inbox and flash a skeleton — and keeps it on
  /// failure too, because a dropped connection is not an emptied inbox.
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (_inFlight) return;
    _inFlight = true;

    final had = state.valueOrNull;
    if (showLoading && had == null) state = const AsyncValue.loading();

    try {
      final res = await ApiClient.getNotifications();
      final list = res['data'] as List<dynamic>? ?? [];
      if (!mounted) return;
      state = AsyncValue.data(NotificationModel.listFromJson(list));
    } catch (e, st) {
      if (!mounted) return;
      // Only surface the failure when there is nothing to fall back on.
      if (had == null) state = AsyncValue.error(e, st);
    } finally {
      _inFlight = false;
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
      await refresh();
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
      await refresh();
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
