import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = _kindOf(notification.type);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead ? colors.card : colors.card,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kind.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  kind.icon,
                  color: kind.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.timeAgo,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The icon and tint for a notification, from the `type` the API actually
  /// sends.
  ///
  /// The old map knew `booking`, `game`, `payment` and `promo` — four names the
  /// backend has never sent. Every real notification therefore fell through to
  /// a grey bell, so a new follower, a cancelled booking and a game invite were
  /// visually identical and nothing in the list said what had happened. The
  /// backend namespaces its types (`booking_*`, `game_*`, `coach_*`,
  /// `player_*`), so the prefix is what this matches on — a type added later
  /// lands in the right family without a change here.
  ///
  /// Anything that went wrong for the reader — a cancellation, a rejection —
  /// is checked first and tinted [AppColors.error], whatever family it is in:
  /// "your booking was cancelled" must not look like "your booking is
  /// confirmed".
  static _Kind _kindOf(String type) {
    final t = type.toLowerCase();

    if (t.contains('cancel') || t.contains('reject')) {
      return const _Kind(Icons.cancel_outlined, AppColors.error);
    }
    if (t.startsWith('player_')) {
      return const _Kind(Icons.person_add_alt_1_rounded, AppColors.info);
    }
    if (t.startsWith('game')) {
      return t.contains('invite')
          ? const _Kind(Icons.mark_email_unread_rounded, AppColors.accent)
          : const _Kind(Icons.sports_cricket_rounded, AppColors.accent);
    }
    if (t.startsWith('coach')) {
      return const _Kind(Icons.sports_rounded, AppColors.primary);
    }
    if (t.contains('payment') || t.contains('collected')) {
      return const _Kind(Icons.payments_rounded, AppColors.info);
    }
    if (t.startsWith('booking')) {
      return t.contains('approve')
          ? const _Kind(Icons.verified_rounded, AppColors.success)
          : const _Kind(Icons.event_available_rounded, AppColors.primary);
    }
    if (t.contains('approved')) {
      return const _Kind(Icons.verified_rounded, AppColors.success);
    }
    if (t.startsWith('promo')) {
      return const _Kind(Icons.local_offer_rounded, AppColors.accent);
    }
    return const _Kind(Icons.notifications_rounded, AppColors.neutral);
  }
}

/// One notification family: what it looks like, and what colour it carries.
class _Kind {
  final IconData icon;
  final Color color;

  const _Kind(this.icon, this.color);
}
