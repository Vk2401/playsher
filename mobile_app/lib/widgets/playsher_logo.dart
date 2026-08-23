import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Which colour the logo paints itself.
///
/// The registered artwork ships one shape per element, not one file per colour:
/// `playsher_mark.png` and `playsher_wordmark.png` are white silhouettes whose
/// alpha channel *is* the artwork, so both brand versions come out of the same
/// asset and cannot drift apart. [PlaysherTone.auto] is what almost every call
/// site wants.
enum PlaysherTone {
  /// Brand blue on a light surface, white on a dark one — read from the theme.
  auto,

  /// Brand blue. For a logo sitting on a white or light card.
  blue,

  /// White. For a logo sitting on a brand-blue fill, a photo, or a dark sheet.
  white,

  /// The brand's deep navy, whatever the surface. For the wordmark on a fixed
  /// light frame — the splash — where [ink] would come out white in dark mode.
  navy,

  /// The surface's own text colour — black on light, white on dark, as the
  /// brand sheet sets the wordmark. Use it when the mark beside it already
  /// carries the blue and a second blue would flatten the lockup.
  ink,
}

/// The Playsher logo, in the three shapes the brand sheet defines.
///
/// * [PlaysherLogo.mark] — the P on its own, tinted.
/// * [PlaysherLogo.tile] — the P inside the brand-blue rounded square, exactly
///   as the launcher icon draws it. Full colour, so [tone] does not apply.
/// * [PlaysherLogo.wordmark] — the PLAYSHER lettering alone, tinted.
/// * [PlaysherLogo.lockup] — the mark beside the wordmark.
class PlaysherLogo extends StatelessWidget {
  const PlaysherLogo.mark({super.key, this.size = 48, this.tone = PlaysherTone.auto})
      : _shape = _Shape.mark;

  const PlaysherLogo.tile({super.key, this.size = 72})
      : _shape = _Shape.tile,
        tone = PlaysherTone.auto;

  const PlaysherLogo.wordmark({super.key, this.size = 24, this.tone = PlaysherTone.auto})
      : _shape = _Shape.wordmark;

  const PlaysherLogo.lockup({super.key, this.size = 32, this.tone = PlaysherTone.auto})
      : _shape = _Shape.lockup;

  final _Shape _shape;

  /// Height of the logo in logical pixels. Width follows the artwork.
  final double size;

  final PlaysherTone tone;

  static const _markAsset = 'assets/logo/playsher_mark.png';
  static const _wordmarkAsset = 'assets/logo/playsher_wordmark.png';
  static const _tileAsset = 'assets/logo/playsher_tile.png';

  Color _resolve(BuildContext context) => switch (tone) {
        PlaysherTone.blue => AppColors.primary,
        PlaysherTone.white => Colors.white,
        PlaysherTone.navy => AppColors.brandInk,
        PlaysherTone.ink => context.colors.textPrimary,
        PlaysherTone.auto => Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Playsher',
      image: true,
      child: switch (_shape) {
        _Shape.tile => Image.asset(_tileAsset, height: size, width: size),
        _Shape.mark => _tinted(context, _markAsset, size),
        _Shape.wordmark => _tinted(context, _wordmarkAsset, size),
        _Shape.lockup => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _tinted(context, _markAsset, size),
              SizedBox(width: size * 0.32),
              // The wordmark is a wide, short shape; scaling it to the mark's
              // full height would tower over it, so it takes a share instead.
              Image.asset(
                _wordmarkAsset,
                height: size * 0.56,
                color: tone == PlaysherTone.auto
                    ? context.colors.textPrimary
                    : _resolve(context),
                colorBlendMode: BlendMode.srcIn,
                excludeFromSemantics: true,
              ),
            ],
          ),
      },
    );
  }

  Widget _tinted(BuildContext context, String asset, double height) => Image.asset(
        asset,
        height: height,
        color: _resolve(context),
        colorBlendMode: BlendMode.srcIn,
        excludeFromSemantics: true,
      );
}

enum _Shape { mark, tile, wordmark, lockup }
