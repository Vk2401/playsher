import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
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
          SliverToBoxAdapter(
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // Avatar
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                AppColors.accent.withValues(alpha: 0.2),
                            width: 3,
                          ),
                        ),
                      ),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: colors.input,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.accent, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            user?.initials ?? '?',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.edit_rounded,
                              size: 18, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    (user?.name ?? 'Player').toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? user?.mobile ?? '',
                    style: TextStyle(
                        fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  // Stats
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: colors.input,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        _StatItem(
                            value: '$totalBookings',
                            label: 'BOOKINGS',
                            colors: colors),
                        Container(
                            width: 1,
                            height: 36,
                            color: colors.border),
                        _StatItem(
                            value: '${user?.gamesPlayed ?? 0}',
                            label: 'GAMES',
                            colors: colors),
                        Container(
                            width: 1,
                            height: 36,
                            color: colors.border),
                        _StatItem(
                            value: user?.rating != null && user!.rating > 0
                                ? user.rating.toStringAsFixed(1)
                                : '\u2014',
                            label: 'RATING',
                            colors: colors),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          // Menu
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MenuItem(
                  icon: Icons.event_note_rounded,
                  iconColor: AppColors.primary,
                  title: 'My Bookings',
                  onTap: () => context.push('/my-bookings'),
                ),
                const SizedBox(height: 10),
                _MenuItem(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFFF4D4D),
                  title: 'Saved Turfs',
                  onTap: () => context.push('/saved-turfs'),
                ),
                const SizedBox(height: 10),
                _MenuItem(
                  icon: Icons.notifications_rounded,
                  iconColor: const Color(0xFFFFB300),
                  title: 'Notifications',
                  onTap: () => context.push('/notifications'),
                ),
                const SizedBox(height: 10),
                _MenuItem(
                  icon: Icons.settings_rounded,
                  iconColor: const Color(0xFF2196F3),
                  title: 'Settings',
                  onTap: () => context.push('/settings'),
                ),
                const SizedBox(height: 10),
                _MenuItem(
                  icon: Icons.help_rounded,
                  iconColor: const Color(0xFFFF9800),
                  title: 'Help & Support',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                // Logout
                GestureDetector(
                  onTap: () => _logout(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.elevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.logout_rounded,
                              size: 18, color: AppColors.error),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    '${AppConstants.appName.toUpperCase()} V1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '\u00a9 2025 ${AppConstants.appName}. All rights reserved.',
                    style:
                        TextStyle(fontSize: 10, color: colors.border),
                  ),
                ),
                const SizedBox(height: 24),
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
            child: Text('Cancel',
                style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(color: AppColors.error)),
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

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final AppColors colors;

  const _StatItem(
      {required this.value, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
