import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_colors.dart';
import '../models/ground_model.dart';
import '../providers/favorites_provider.dart';

/// Where the heart is sitting, which is all that changes about it.
enum FavoriteButtonTone {
  /// On a venue photograph: white with its own shadow, because the photo
  /// underneath is whatever the owner uploaded.
  onImage,

  /// On a card or a page surface, where the theme's own ink is legible.
  onSurface,
}

/// The save control on a ground.
///
/// Reads and writes the list itself rather than taking `isFavorite` and a
/// callback from whatever is drawing it: every card that shows one is then
/// consistent by construction, and a card cannot be wired up with a heart that
/// does not respond. The state flips on tap — [FavoritesNotifier.toggle] is
/// optimistic — so this is as fast as a rebuild.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.ground,
    this.tone = FavoriteButtonTone.onImage,
    this.visualSize = 26,
  });

  final GroundModel ground;
  final FavoriteButtonTone tone;

  /// The heart's drawn size. The *target* is always 44.
  final double visualSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(favoriteIdsProvider).contains(ground.id);
    final unsavedColor = switch (tone) {
      FavoriteButtonTone.onImage => AppColors.onImage,
      FavoriteButtonTone.onSurface => context.colors.textSecondary,
    };

    return Semantics(
      label: saved ? 'Remove from saved' : 'Save this ground',
      button: true,
      selected: saved,
      child: GestureDetector(
        onTap: () => ref.read(favoritesProvider.notifier).toggle(ground),
        behavior: HitTestBehavior.opaque,
        // 44 for the finger, whatever the heart is drawn at.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: SizedBox(
              width: visualSize,
              height: visualSize,
              child: Icon(
                // The filled shape carries the state as well as the colour, so
                // it still reads as saved without seeing red.
                saved ? Icons.favorite : Icons.favorite_border,
                size: visualSize,
                color: saved ? AppColors.error : unsavedColor,
                shadows: tone == FavoriteButtonTone.onImage
                    ? [
                        // A drop shadow rather than a scrim disc: the disc read
                        // as a button the user could not name, and the heart is
                        // legible over a bright photo as long as it carries its
                        // own shadow.
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
