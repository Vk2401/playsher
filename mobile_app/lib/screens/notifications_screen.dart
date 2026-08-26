import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_error.dart';
import '../core/app_colors.dart';
import '../models/notification_model.dart';
import '../providers/notifications_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/notification_card.dart';
import '../widgets/shimmer_loader.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final async = ref.watch(notificationsProvider);

    final all = async.valueOrNull ?? const <NotificationModel>[];
    final unread = all.where((n) => !n.isRead).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllAsRead(),
              child:
                  const Text('Mark all read', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Column(
          children: [
            SizedBox(height: 8),
            NotificationShimmer(),
            NotificationShimmer(),
            NotificationShimmer(),
          ],
        ),
        error: (e, _) => ErrorView(
          message:
              apiErrorMessage(e, fallback: 'Could not load your notifications'),
          onRetry: () => ref.read(notificationsProvider.notifier).load(),
        ),
        data: (_) => Column(
          children: [
            TabBar(
              controller: _tabCtrl,
              tabs: [
                Tab(text: 'All (${all.length})'),
                Tab(text: 'Unread (${unread.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _NotificationList(
                    items: all,
                    emptyTitle: 'No notifications yet',
                    emptyBody:
                        'Booking updates and game invites will appear here.',
                  ),
                  _NotificationList(
                    items: unread,
                    emptyTitle: 'All caught up!',
                    emptyBody: "You've read everything.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  final List<NotificationModel> items;
  final String emptyTitle;
  final String emptyBody;

  const _NotificationList({
    required this.items,
    required this.emptyTitle,
    required this.emptyBody,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded,
                  size: 56, color: colors.textSecondary),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: colors.card,
      onRefresh: () => ref.read(notificationsProvider.notifier).load(),
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => NotificationCard(
          notification: items[i],
          // Marking it read is not the point of the tap — going where the
          // notification points is. A row about a booking that opens nothing
          // reads as broken.
          onTap: () => _open(context, ref, items[i]),
          onDismiss: () =>
              ref.read(notificationsProvider.notifier).remove(items[i].id),
        ),
      ),
    );
  }
}

/// Mark it read, then follow it. The path is a router location the server
/// chose, so an absent or unrecognised one simply does nothing rather than
/// throwing on a route this build does not have.
void _open(BuildContext context, WidgetRef ref, NotificationModel notification) {
  ref.read(notificationsProvider.notifier).markAsRead(notification.id);
  final path = notification.actionPath;
  if (path == null || !path.startsWith('/')) return;
  context.push(path);
}
