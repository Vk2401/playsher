import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// One onboarding page's content: the hero, the two-tone headline, the deck,
/// and the three feature rows.
///
/// Only the content — the Skip link, the dots and the button live in the
/// screen's fixed chrome, so they hold still while pages slide under them.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.content});

  final OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    final frame = context.frame;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(content: content),
          const SizedBox(height: 24),

          // Two-tone headline: the subject in navy, the promise in brand blue.
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.3,
                color: frame.ink,
              ),
              children: [
                TextSpan(text: '${content.title}\n'),
                TextSpan(
                  // brandText, not primary: the deep brand blue drops to
                  // 3.5:1 on the dark page.
                  style: TextStyle(color: context.colors.brandText),
                  text: content.titleAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            content.deck,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: frame.body,
            ),
          ),
          const SizedBox(height: 26),
          for (final feature in content.features) ...[
            _FeatureRow(feature: feature),
            if (feature != content.features.last) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

/// The page's illustration.
///
/// The three rendered illustrations are artwork, not something a painter can
/// stand in for convincingly, so this loads them from `assets/images/` and
/// falls back to a clean glyph scene while a file is missing — an onboarding
/// that still reads correctly rather than a red error box.
///
/// The artwork carries its own light ground, so in dark mode it sits on a
/// rounded panel of that same light colour rather than bleeding a hard white
/// rectangle into the page. In light mode the panel is the page colour and
/// disappears, which is why it is not conditional: one code path, and the
/// illustration always meets its own background.
class _Hero extends StatelessWidget {
  const _Hero({required this.content});

  final OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: FramePalette.light.page,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Image.asset(
        content.illustration,
        fit: BoxFit.contain,
        errorBuilder: (context, _, __) => ColoredBox(
          color: context.frame.page,
          child: _GlyphScene(content: content),
        ),
      ),
    );
  }
}

/// The stand-in: the page's own glyph on a soft brand disc, flanked by the two
/// feature glyphs on floating tiles — the shape of the real illustrations.
class _GlyphScene extends StatelessWidget {
  const _GlyphScene({required this.content});

  final OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 176,
          height: 176,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.frame.tile,
          ),
          child: Icon(content.heroIcon,
              size: 88, color: context.colors.brandText),
        ),
        Align(
          alignment: const Alignment(-0.78, -0.62),
          child: _FloatingTile(icon: content.features.first.icon),
        ),
        Align(
          alignment: const Alignment(0.78, -0.34),
          child: _FloatingTile(icon: content.features.last.icon),
        ),
      ],
    );
  }
}

class _FloatingTile extends StatelessWidget {
  const _FloatingTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandInk.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 26, color: context.colors.brandText),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final OnboardingFeature feature;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.frame.tile,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(feature.icon,
              size: 24, color: context.colors.brandText),
        ),
        const SizedBox(width: 14),
        // Flexible, not a fixed-height box: these are two-line bodies that
        // grow at 1.3x text scale.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feature.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.frame.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                feature.body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: context.frame.body,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One bullet in a page's feature list.
class OnboardingFeature {
  const OnboardingFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Everything one onboarding page says.
class OnboardingContent {
  const OnboardingContent({
    required this.illustration,
    required this.heroIcon,
    required this.title,
    required this.titleAccent,
    required this.deck,
    required this.features,
  });

  /// Asset path of the rendered illustration. Missing files fall back to a
  /// glyph scene rather than failing the page.
  final String illustration;

  /// The glyph that stands in for [illustration] while it is missing.
  final IconData heroIcon;

  /// First headline line, in navy.
  final String title;

  /// Second headline line, in brand blue.
  final String titleAccent;

  final String deck;
  final List<OnboardingFeature> features;
}
