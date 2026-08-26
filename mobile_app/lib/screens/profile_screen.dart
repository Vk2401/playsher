import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/animations.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/bookings_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final bookings = ref.watch(bookingsProvider);
    final totalBookings = bookings.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // The header bleeds under the status bar, so it pads itself with
          // MediaQuery.padding.top instead of sitting inside a SafeArea.
          //
          // Header and stats card share one sliver: slivers paint in reverse
          // order, so a stats card in its own sliver below the header was
          // painted *under* it and the numbers vanished into the blue.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                  bottom: _Header.statsOverlap + 24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _Header(user: user),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -_Header.statsOverlap,
                    child: _StatsCard(
                      bookings: '$totalBookings',
                      games: '${user?.gamesPlayed ?? 0}',
                      rating: user != null && user.rating > 0
                          ? user.rating.toStringAsFixed(1)
                          : '—',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _GroupLabel('Activity'),
                _MenuGroup(
                  items: [
                    _MenuEntry(
                      icon: Icons.event_note_rounded,
                      tint: AppColors.primary,
                      title: 'My Bookings',
                      subtitle: 'Upcoming and past slots',
                      onTap: () => context.push('/my-bookings'),
                    ),
                    _MenuEntry(
                      icon: Icons.sports_rounded,
                      tint: AppColors.info,
                      title: 'My Coaching',
                      subtitle: 'Sessions booked with coaches',
                      onTap: () => context.push('/my-sessions'),
                    ),
                    _MenuEntry(
                      icon: Icons.favorite_rounded,
                      tint: AppColors.error,
                      title: 'Saved Turfs',
                      subtitle: 'Venues you shortlisted',
                      onTap: () => context.push('/saved-turfs'),
                    ),
                    _MenuEntry(
                      icon: Icons.notifications_rounded,
                      tint: AppColors.warning,
                      title: 'Notifications',
                      subtitle: 'Booking and game updates',
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _GroupLabel('Account'),
                _MenuGroup(
                  items: [
                    _MenuEntry(
                      icon: Icons.person_rounded,
                      tint: AppColors.info,
                      title: 'Edit Profile',
                      subtitle: 'Name, email and city',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    _MenuEntry(
                      icon: Icons.settings_rounded,
                      tint: AppColors.neutral,
                      title: 'Settings',
                      subtitle: 'Theme, location and app info',
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _LogoutButton(onTap: () => _logout(context, ref)),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    '${AppConstants.appName.toUpperCase()} V1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '© 2025 ${AppConstants.appName}. All rights reserved.',
                    style: TextStyle(fontSize: 10, color: colors.textSecondary),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

/// Brand-blue header the stats card overlaps. Everything inside it sits on
/// [AppColors.primary] in both themes, so it uses the `onPrimary` pair rather
/// than the brightness-dependent surface tokens.
class _Header extends StatelessWidget {
  /// How far the stats card hangs below the header's bottom edge.
  static const double statsOverlap = 44;

  final UserModel? user;

  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final name = user?.name.trim();
    final contact = user?.email ?? user?.mobile ?? '';
    final city = user?.city;

    return Container(
      width: double.infinity,
      // The stats card is ~78 tall and hangs [statsOverlap] below the header,
      // so it reaches ~34 back up into it — this bottom padding is that
      // intrusion plus clearance, otherwise the card sits on the email line.
      padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 58),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Both stops are derived from the one brand hex, so re-branding
            // stays a single-line change in AppColors.
            Color.lerp(AppColors.primary, AppColors.onPrimary, 0.12)!,
            Color.lerp(AppColors.primary, AppColors.onAccent, 0.28)!,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          _Avatar(user: user),
          const SizedBox(height: 14),
          Text(
            (name == null || name.isEmpty) ? 'Player' : name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.onPrimary,
              letterSpacing: 0.2,
            ),
          ),
          if (contact.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              contact,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onPrimaryMuted,
              ),
            ),
          ],
          if (city != null && city.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.onPrimary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place_rounded,
                      size: 14, color: AppColors.onPrimary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserModel? user;

  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatar?.trim();
    final initials = user?.initials ?? '?';

    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.onPrimary.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.onPrimary.withValues(alpha: 0.5),
                width: 3,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: (avatar != null && avatar.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _Initials(initials),
                    placeholder: (_, __) => _Initials(initials),
                  )
                : _Initials(initials),
          ),
          Positioned(
            right: -6,
            bottom: -6,
            child: Semantics(
              label: 'Edit profile',
              button: true,
              child: GestureDetector(
                onTap: () => context.push('/profile/edit'),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.onPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 17, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;

  const _Initials(this.initials);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w800,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}

// ── Stats ───────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final String bookings;
  final String games;
  final String rating;

  const _StatsCard({
    required this.bookings,
    required this.games,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.onAccent.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
              icon: Icons.event_available_rounded,
              value: bookings,
              label: 'BOOKINGS'),
          _StatDivider(color: colors.border),
          _StatItem(
              icon: Icons.sports_soccer_rounded, value: games, label: 'GAMES'),
          _StatDivider(color: colors.border),
          _StatItem(
              icon: Icons.star_rounded, value: rating, label: 'RATING'),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;

  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 38, color: color);
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: colors.brandText),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu ────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.colors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MenuEntry {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuEntry({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

/// One rounded card holding several rows, hairline-separated — a grouped list
/// reads as a single surface instead of five floating slabs.
class _MenuGroup extends StatelessWidget {
  final List<_MenuEntry> items;

  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 68),
                child: Divider(height: 1, thickness: 1, color: colors.border),
              ),
            _MenuRow(entry: items[i]),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuEntry entry;

  const _MenuRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppAnimations.tapScale(
      onTap: entry.onTap,
      pressedScale: 0.99,
      child: Semantics(
        label: entry.title,
        button: true,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: entry.tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, size: 19, color: entry.tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppAnimations.tapScale(
      onTap: onTap,
      pressedScale: 0.99,
      child: Semantics(
        label: 'Logout',
        button: true,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.error.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
              SizedBox(width: 10),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
