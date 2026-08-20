import 'package:flutter/material.dart';

/// Semantic color tokens for light and dark themes.
class AppColors {
  final Color background;
  final Color card;
  final Color input;
  final Color elevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  // ── Shared across themes ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF00D261);
  static const Color accent = Color(0xFFCCFF00);
  static const Color error = Color(0xFFFF4D4D);
  static const Color star = Color(0xFFCCFF00);

  /// Foreground that sits on a [primary] / [accent] fill. Always black —
  /// the neon fills are too light for white text in either theme.
  static const Color onPrimary = Color(0xFF000000);

  /// Muted variant of [onPrimary] for secondary text on a neon fill.
  static const Color onPrimaryMuted = Color(0x8A000000);

  // ── Semantic status tokens ────────────────────────────────────────────────
  // Deliberately theme-independent: a "pending" badge must read the same in
  // both themes. Tuned to stay legible on both the light and dark surfaces.
  static const Color warning = Color(0xFFF59E0B); // pending / intermediate
  static const Color info = Color(0xFF3B82F6); // completed / verified
  static const Color neutral = Color(0xFF8A8A8E); // unknown / inactive

  const AppColors._({
    required this.background,
    required this.card,
    required this.input,
    required this.elevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const dark = AppColors._(
    background: Color(0xFF000000),
    card: Color(0xFF121212),
    input: Color(0xFF1A1A1A),
    elevated: Color(0xFF111111),
    border: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA0A0A0),
  );

  static const light = AppColors._(
    background: Color(0xFFF5F5F5),
    card: Color(0xFFFFFFFF),
    input: Color(0xFFF0F0F0),
    elevated: Color(0xFFFFFFFF),
    border: Color(0xFFE0E0E0),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF757575),
  );

  /// Resolve colors based on current brightness.
  static AppColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

/// Convenience extension so widgets can write `context.colors.card`.
extension AppColorsExtension on BuildContext {
  AppColors get colors => AppColors.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
