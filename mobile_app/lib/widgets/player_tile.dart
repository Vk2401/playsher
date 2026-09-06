import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../models/player_model.dart';
import '../providers/players_provider.dart';

/// One player in a list: avatar, name, handle, and one action.
///
/// The action differs by context, which is why it is passed in rather than
/// assumed — a search result offers Follow, an invite sheet offers Invite, and
/// a squad row offers nothing at all.
class PlayerTile extends StatelessWidget {
  final PlayerCard player;
  final VoidCallback? onTap;

  /// The control on the right. Null leaves the row informational.
  final Widget? trailing;

  const PlayerTile({
    super.key,
    required this.player,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: onTap != null,
      // The trailing control is its own focusable node, so it is not excluded.
      label: '${player.name}, ${player.handle}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              PlayerAvatar(
                name: player.name,
                avatar: player.avatar,
                initials: player.initials,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.name.trim().isEmpty ? player.handle : player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      player.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12.5, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A player's face, or their initials when they have not set one.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? avatar;
  final String initials;
  final double size;

  const PlayerAvatar({
    super.key,
    required this.name,
    required this.initials,
    this.avatar,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = avatar?.trim();
    final hasPhoto = url != null && url.isNotEmpty;

    Widget fallback() => Container(
          width: size,
          height: size,
          color: AppColors.primary.withValues(alpha: 0.14),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              color: colors.brandText,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800,
            ),
          ),
        );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback(),
                errorWidget: (_, __, ___) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}

/// Follow / Following, bound to the notifier's per-player in-flight flag.
///
/// Both calls are idempotent server-side, so a double tap cannot corrupt the
/// relationship — but the button still disables itself while a request is out,
/// because a control that looks tappable and does nothing reads as broken.
class FollowButton extends ConsumerWidget {
  final int playerId;
  final bool isFollowing;

  /// Hidden entirely for yourself — there is no relationship to change.
  final bool isSelf;

  /// A wider button for a profile header; the compact one suits a list row.
  final bool expanded;

  /// Called with the new state after the request settles, so a screen holding
  /// its own copy (a profile header's follower count) can move with it.
  final void Function(bool nowFollowing, int? followersCount)? onChanged;

  const FollowButton({
    super.key,
    required this.playerId,
    required this.isFollowing,
    this.isSelf = false,
    this.expanded = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    if (isSelf) return const SizedBox.shrink();

    final busy = ref.watch(followActionsProvider).contains(playerId);

    Future<void> toggle() async {
      final count = await ref
          .read(followActionsProvider.notifier)
          .toggle(playerId, isFollowing: isFollowing);
      onChanged?.call(!isFollowing, count);
    }

    final label = isFollowing ? 'Following' : 'Follow';
    final size = Size(expanded ? double.infinity : 104, 44);

    if (isFollowing) {
      return SizedBox(
        height: 44,
        width: expanded ? double.infinity : null,
        child: OutlinedButton(
          onPressed: busy ? null : toggle,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: busy
              ? const _Spinner()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 16, color: colors.brandText),
                    const SizedBox(width: 5),
                    Text(label, style: const TextStyle(fontSize: 13.5)),
                  ],
                ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      width: expanded ? double.infinity : null,
      child: ElevatedButton(
        onPressed: busy ? null : toggle,
        style: ElevatedButton.styleFrom(
          minimumSize: size,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: busy
            ? const _Spinner(onFill: true)
            : Text(label, style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  /// A spinner on the filled Follow button needs the on-primary foreground;
  /// on the outlined Following button the theme's own colour is correct.
  final bool onFill;

  const _Spinner({this.onFill = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: onFill ? AppColors.onPrimary : null,
        ),
      );
}
