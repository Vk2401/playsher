import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // User info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    user?.initials ?? '?',
                    style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Player', style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(user?.email ?? user?.mobile ?? '', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.edit, size: 18, color: colors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Theme toggle
          Text('Appearance', style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                _ThemeButton(label: 'Light', icon: Icons.light_mode, selected: themeMode == ThemeMode.light, onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.light)),
                _ThemeButton(label: 'Dark', icon: Icons.dark_mode, selected: themeMode == ThemeMode.dark, onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.dark)),
                _ThemeButton(label: 'System', icon: Icons.settings_brightness, selected: themeMode == ThemeMode.system, onTap: () => ref.read(themeProvider.notifier).setTheme(ThemeMode.system)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account settings
          Text('ACCOUNT', style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 8),
          _SettingsTile(icon: Icons.person, title: 'Edit Profile', colors: colors, onTap: () {}),
          _SettingsTile(icon: Icons.lock, title: 'Privacy', colors: colors, onTap: () {}),
          _SettingsTile(icon: Icons.notifications, title: 'Notifications', colors: colors, onTap: () => context.push('/notifications')),
          const SizedBox(height: 24),

          // App settings
          Text('APP', style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 8),
          _SettingsTile(icon: Icons.language, title: 'Language', trailing: 'English', colors: colors, onTap: () {}),
          _SettingsTile(icon: Icons.info, title: 'About', colors: colors, onTap: () {}),
          _SettingsTile(icon: Icons.description, title: 'Terms of Service', colors: colors, onTap: () {}),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
              ),
              child: const Text('Logout'),
            ),
          ),
          const SizedBox(height: 24),

          // Version footer
          Center(
            child: Text(
              '${AppConstants.appName} v1.0.0',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? Colors.black : colors.textSecondary),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.black : colors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final AppColors colors;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.title, this.trailing, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: colors.textSecondary),
      title: Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
      trailing: trailing != null
          ? Text(trailing!, style: TextStyle(color: colors.textSecondary, fontSize: 13))
          : Icon(Icons.chevron_right, size: 18, color: colors.textSecondary),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
