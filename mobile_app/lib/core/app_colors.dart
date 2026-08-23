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

  /// Brand blue as *text* on a card or background surface.
  ///
  /// [primary] is a deep blue, so the light theme can paint ink with it
  /// directly (6.02:1 on a white card). Dark is now the side that needs a
  /// variant: [primary] on black is 3.49:1, so dark lightens the same hue
  /// until small text is legible.
  final Color brandText;

  /// Green as *text* on a card or background surface — "19 of 19 left today".
  /// [success] is a deep green tuned for a white card; on black it drops under
  /// AA, so dark lightens the same hue.
  final Color successText;

  // ── Shared across themes ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF0061C2);

  /// Availability, savings, "on track". Deep enough for white text on a fill
  /// and for ink on a white card. Pair it with words — never colour alone.
  static const Color success = Color(0xFF15803D);

  /// [success] one step darker, for a filled button that sits *inside* a
  /// success-tinted panel and would otherwise vanish into it.
  static const Color successDark = Color(0xFF0B5D34);

  static const Color accent = Color(0xFFCCFF00);
  static const Color error = Color(0xFFFF4D4D);
  static const Color star = Color(0xFFCCFF00);

  // ── Derived from [primary] ────────────────────────────────────────────────
  // The brand hex is declared exactly once, above. Everything that needs the
  // same blue at another opacity — or in another notation — is computed from
  // it, so changing the brand means editing one line.

  /// [primary] behind a selected chip's label.
  static final Color primarySelected = primary.withValues(alpha: 0.2);

  /// [primary] behind the selected bottom-navigation destination.
  static final Color primaryIndicator = primary.withValues(alpha: 0.1);

  /// [primary] as the `#RRGGBB` string Razorpay's checkout theme expects.
  /// Razorpay takes CSS notation, not a Dart [Color], and this is the only
  /// place that conversion is allowed to happen.
  static String get primaryHex =>
      '#${(primary.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Foreground that sits on a [primary] fill. White — [primary] is a deep
  /// blue at 6.02:1 against white and only 3.49:1 against black, so black
  /// labels on a primary button fail AA. [accent] is still a light neon and
  /// keeps [onAccent] below.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Muted variant of [onPrimary] for secondary text on a [primary] fill.
  static const Color onPrimaryMuted = Color(0x8AFFFFFF);

  /// Foreground on an [accent] / [star] fill, which stayed neon lime and is
  /// far too light for white text.
  static const Color onAccent = Color(0xFF000000);

  /// The brand blue over an [imageScrim] or a dark hero. [primary] is only
  /// 3.49:1 on black, so anything brand-coloured on a photo uses this instead.
  static const Color brandOnImage = Color(0xFF5AA9FF);

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

  /// The pill colour for a sport badge on a venue photo.
  ///
  /// A venue is scanned for its sport before its name, so the badge carries a
  /// hue as well as the word. Every value here is dark enough for [onImage]
  /// text in both themes; anything unlisted falls back to the brand.
  static Color sportTint(String sport) => switch (sport.trim().toLowerCase()) {
        'cricket' => const Color(0xFF0F7A3D),
        'football' || 'soccer' || 'futsal' => primary,
        'tennis' => const Color(0xFF9A6700),
        'badminton' => const Color(0xFF6D28D9),
        'basketball' => const Color(0xFFB4460C),
        'volleyball' => const Color(0xFF0E7490),
        'hockey' => const Color(0xFF9D174D),
        _ => primary,
      };

  const AppColors._({
    required this.background,
    required this.card,
    required this.input,
    required this.elevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brandText,
    required this.successText,
  });

  static const dark = AppColors._(
    background: Color(0xFF000000),
    card: Color(0xFF121212),
    input: Color(0xFF1A1A1A),
    elevated: Color(0xFF111111),
    border: Color(0xFF2A2A2A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA0A0A0),
    brandText: Color(0xFF5AA9FF),
    successText: Color(0xFF4ADE80),
  );

  static const light = AppColors._(
    background: Color(0xFFF5F5F5),
    card: Color(0xFFFFFFFF),
    input: Color(0xFFF0F0F0),
    elevated: Color(0xFFFFFFFF),
    border: Color(0xFFE0E0E0),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF757575),
    brandText: primary,
    successText: success,
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
