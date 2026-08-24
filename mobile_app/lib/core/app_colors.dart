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

  /// The app's one accent colour: the same blue as [primary]. Was a neon lime
  /// (`0xFFCCFF00`), then a violet meant to stay distinct from [primary] — the
  /// violet didn't land, so a selected chip, an active slot, and a status
  /// badge now share [primary]'s blue like everything else in the app.
  static const Color accent = primary;
  static const Color error = Color(0xFFFF4D4D);

  /// Rating star, on any surface. The same amber as [rating] — a star reads
  /// as a star because it's gold, on a card or over a photo scrim alike.
  static const Color star = Color(0xFFFFB300);

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

  /// [primary] lifted, for the top-left end of a brand gradient — the login
  /// screen's Send OTP button. A flat fill reads as a slab at that size.
  static const Color primaryLift = Color(0xFF2E7FE0);

  /// Foreground that sits on a [primary] fill. White — [primary] is a deep
  /// blue at 6.02:1 against white and only 3.49:1 against black, so black
  /// labels on a primary button fail AA.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Muted variant of [onPrimary] for secondary text on a [primary] fill.
  static const Color onPrimaryMuted = Color(0x8AFFFFFF);

  /// Foreground on an [accent] fill. Same as [onPrimary] — [accent] is
  /// [primary].
  static const Color onAccent = onPrimary;

  /// The deep navy the brand sheet sets the wordmark in, on a light surface.
  /// Darker than [primary] on purpose: in the lockup the mark carries the blue,
  /// and a second [primary] beside it flattens the two into one shape.
  static const Color brandInk = Color(0xFF0B2A5B);

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

  /// Rating star drawn on a card surface. Same amber as [star] — kept as its
  /// own token because a few call sites reached for "rating" by name before
  /// [star] existed.
  static const Color rating = Color(0xFFFFB300);

  // ── Sports equipment ──────────────────────────────────────────────────────
  // The decorative props scattered behind the login page. Theme-independent on
  // purpose: a cricket ball is red in the dark too. `SportProp` dims the whole
  // scatter on the dark page rather than recolouring any of these.

  /// A basketball: the leather, and the seams pressed into it.
  static const Color propBasketball = Color(0xFFD9722B);
  static const Color propBasketballLine = Color(0xFF3D2313);

  /// A cricket ball: the lacquered leather, and the stitched seam.
  static const Color propCricket = Color(0xFF9E1F26);
  static const Color propCricketSeam = Color(0xFFF2E7D0);

  /// A tennis ball, and the felt seam curving round it.
  static const Color propTennis = Color(0xFFC6DE4A);
  static const Color propTennisSeam = Color(0xFFFAFDF0);

  /// A volleyball's panels.
  static const Color propVolley = Color(0xFFF4F6F9);
  static const Color propVolleyPanel = Color(0xFF2F6FB8);

  /// A cricket bat: the willow blade, its edge, and the rubber grip.
  static const Color propWillow = Color(0xFFE3C089);
  static const Color propWillowEdge = Color(0xFFC29B60);
  static const Color propGrip = Color(0xFF23303F);

  // ── Illustration: the shield the OTP screen is verified behind ────────────
  // Theme-independent for the same reason the props are: it is a picture of an
  // object, not a surface. It carries the brand hue rather than a token so the
  // lit face and the deep edge can be lerped between without three tokens per
  // step.

  /// The shield's face: the lit top-left, the body, and the edge in shadow.
  static const Color shieldLight = Color(0xFF7FB4F5);
  static const Color shieldMid = Color(0xFF2F7FE4);
  static const Color shieldDeep = Color(0xFF0B4FA8);

  /// The padlock on the shield, and the bubble the code arrives in.
  static const Color shieldMetal = Color(0xFFFFFFFF);
  static const Color shieldBubble = Color(0xFFE7F0FD);

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

  /// Night, not absence of light.
  ///
  /// This used to be pure black with grey surfaces, which put a seam right
  /// through the app: the designed frames — splash, onboarding, login, OTP,
  /// the location page — sit on [FramePalette.dark]'s deep navy, so crossing
  /// from the OTP screen to the home screen went from a night sky to a black
  /// void. The surfaces below are that same navy, one step apart each, so
  /// every screen in the app is the same evening.
  ///
  /// [background] matches `FramePalette.dark.page` exactly; the rest step up
  /// from it, and [input] is `FramePalette.dark.tile` — the pale panel the
  /// login flow already uses for a field or an inset strip.
  static const dark = AppColors._(
    background: Color(0xFF0A121F),
    card: Color(0xFF111C2E),
    input: Color(0xFF16253B),
    elevated: Color(0xFF16253B),
    border: Color(0xFF22334D),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9BAFC6),
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

/// The palette of the two designed frames — the splash stadium and onboarding.
///
/// These screens are pictures, not surfaces: a stadium under a floodlit sky,
/// and an illustrated introduction. [AppColors]'s surface tokens describe a
/// card and its border, which is the wrong vocabulary for a horizon, so the
/// frames carry their own set — but they still come in a light and a dark
/// version, because a fresh install follows the device's theme and a light
/// stadium on a dark phone is the seam the whole flow is meant to avoid.
class FramePalette {
  const FramePalette._({
    required this.page,
    required this.skyMid,
    required this.skyHaze,
    required this.ray,
    required this.standLight,
    required this.standDeep,
    required this.skyline,
    required this.lamp,
    required this.glow,
    required this.turfFar,
    required this.turfMid,
    required this.turfNear,
    required this.turfStripe,
    required this.line,
    required this.track,
    required this.ink,
    required this.body,
    required this.tile,
    required this.dot,
  });

  /// The page the frame sits on, and the top of the sky.
  final Color page;

  /// The sky, from [page] down to the stand.
  final Color skyMid;
  final Color skyHaze;

  /// The light sweeping in from the corners.
  final Color ray;

  /// The far stand, and the skyline behind it.
  final Color standLight;
  final Color standDeep;
  final Color skyline;

  /// The floodlight banks: the lamps, and the glow around them.
  final Color lamp;
  final Color glow;

  /// The turf, from the halfway line towards the camera.
  final Color turfFar;
  final Color turfMid;
  final Color turfNear;

  /// The mown stripes, and the painted lines over them.
  final Color turfStripe;
  final Color line;

  /// The loader's unlit track.
  final Color track;

  /// A headline on [page] — the onboarding title, the splash wordmark.
  final Color ink;

  /// Body copy on [page]: the deck, and a feature row's second line.
  final Color body;

  /// The pale tile a feature row's icon sits in.
  final Color tile;

  /// An unvisited page dot.
  final Color dot;

  static const light = FramePalette._(
    page: Color(0xFFF7FAFD),
    skyMid: Color(0xFFE8F2FC),
    skyHaze: Color(0xFFC7E0F7),
    ray: Color(0x38FFFFFF),
    standLight: Color(0xFF6CADEB),
    standDeep: Color(0xFF1F6DC7),
    skyline: Color(0x2E0A3F73),
    lamp: Color(0xFFFFFFFF),
    glow: Color(0x66FFFFFF),
    turfFar: Color(0xFFA8DC72),
    turfMid: Color(0xFF7CC94F),
    turfNear: Color(0xFF9AD86A),
    turfStripe: Color(0x1F1E5B18),
    line: Color(0x99FFFFFF),
    track: Color(0x99FFFFFF),
    ink: AppColors.brandInk,
    body: Color(0xFF4A5A72),
    tile: Color(0xFFEAF2FD),
    dot: Color(0xFFC9D6E5),
  );

  /// Night at the ground: the same stadium under floodlights rather than a
  /// second design. The turf stays green — it is grass, not a surface — but
  /// unlit, and the sky goes to the deep navy the stands already sit in.
  static const dark = FramePalette._(
    page: Color(0xFF0A121F),
    skyMid: Color(0xFF0D1B2E),
    skyHaze: Color(0xFF14304F),
    ray: Color(0x14FFFFFF),
    standLight: Color(0xFF1E5590),
    standDeep: Color(0xFF0A2B50),
    skyline: Color(0x4D000C1A),
    lamp: Color(0xFFFFFFFF),
    glow: Color(0x4DFFFFFF),
    turfFar: Color(0xFF2F7038),
    turfMid: Color(0xFF1E5527),
    turfNear: Color(0xFF2A6631),
    turfStripe: Color(0x1F000000),
    line: Color(0x80FFFFFF),
    track: Color(0x3DFFFFFF),
    ink: Color(0xFFFFFFFF),
    body: Color(0xFF9BAFC6),
    tile: Color(0xFF16253B),
    dot: Color(0xFF2C3E56),
  );

  static FramePalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Convenience extension so a frame can write `context.frame.turfMid`.
extension FramePaletteExtension on BuildContext {
  FramePalette get frame => FramePalette.of(this);
}
