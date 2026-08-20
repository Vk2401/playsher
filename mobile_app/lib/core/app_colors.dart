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

  /// Brand green as *text* on a card or background surface.
  ///
  /// [primary] is a neon tuned to be a fill, not an ink: on the light theme's
  /// white card it lands around 2:1 against the surface, which is why prices
  /// and labels painted with it read as washed out. This is the same hue
  /// darkened until small text is legible; on dark it stays the neon.
  final Color brandText;

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

  // ── Over a photo ──────────────────────────────────────────────────────────
  // A badge sitting on a ground photo cannot use a theme surface: the photo is
  // whatever the owner uploaded, light or dark, in either app theme. These two
  // are the only pair that stays legible over all of them.

  /// Scrim behind a badge or label that sits on top of an image.
  static const Color imageScrim = Color(0xA6000000);

  /// Foreground for text and icons on an [imageScrim].
  static const Color onImage = Color(0xFFFFFFFF);

  /// Rating star drawn on a card surface. [star] is the neon lime used over a
  /// photo scrim; it disappears against a white card, so ratings in a list use
  /// this amber instead.
  static const Color rating = Color(0xFFFFB300);

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
    required this.brandText,
  });

  static const dark = AppColors._(
    background: Color(0xFF000000),
    card: Color(0xFF121212),
    input: Color(0xFF1A1A1A),
    elevated: Color(0xFF111111),
    border: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA0A0A0),
    brandText: primary,
  );

  static const light = AppColors._(
    background: Color(0xFFF5F5F5),
    card: Color(0xFFFFFFFF),
    input: Color(0xFFF0F0F0),
    elevated: Color(0xFFFFFFFF),
    border: Color(0xFFE0E0E0),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF757575),
    brandText: Color(0xFF007F3D),
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
