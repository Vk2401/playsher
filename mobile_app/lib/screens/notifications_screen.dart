import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_card.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
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
    final notifications = ref.watch(notificationsProvider);
    final unread = notifications.where((n) => !n.isRead).toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
              child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.primary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: AppColors.primary,
            dividerColor: colors.border,
            tabs: [
              Tab(text: 'All (${notifications.length})'),
              Tab(text: 'Unread (${unread.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // All
                notifications.isEmpty
                    ? Center(child: Text('No notifications', style: TextStyle(color: colors.textSecondary)))
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (_, i) => NotificationCard(
                          notification: notifications[i],
                          onTap: () => ref.read(notificationsProvider.notifier).markAsRead(notifications[i].id),
                          onDismiss: () => ref.read(notificationsProvider.notifier).remove(notifications[i].id),
                        ),
                      ),
                // Unread
                unread.isEmpty
                    ? Center(child: Text('All caught up!', style: TextStyle(color: colors.textSecondary)))
                    : ListView.builder(
                        itemCount: unread.length,
                        itemBuilder: (_, i) => NotificationCard(
                          notification: unread[i],
                          onTap: () => ref.read(notificationsProvider.notifier).markAsRead(unread[i].id),
                          onDismiss: () => ref.read(notificationsProvider.notifier).remove(unread[i].id),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
