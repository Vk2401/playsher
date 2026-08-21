import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/animations.dart';
import '../core/app_colors.dart';
import '../core/geo.dart';

import '../models/ground_model.dart';
import '../providers/location_provider.dart';

/// A ground, in the two shapes the app uses: a wide card for the featured
/// carousel and a horizontal row for every list.
///
/// It reads the user's position itself rather than taking a distance prop, so
/// that every list in the app gains "how far away" without each screen having
/// to thread it through.
class GroundCard extends ConsumerWidget {
  final GroundModel ground;
  final bool wide;
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;

  const GroundCard({
    super.key,
    required this.ground,
    this.wide = false,
    this.onFavoriteToggle,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userLocationProvider);
    final distanceKm = Geo.distanceKm(
      fromLat: me.latitude,
      fromLng: me.longitude,
      toLat: ground.latitude,
      toLng: ground.longitude,
    );

    return wide
        ? _WideCard(
            ground: ground,
            distanceKm: distanceKm,
            isFavorite: isFavorite,
            onFavoriteToggle: onFavoriteToggle,
          )
        : _HorizontalCard(
            ground: ground,
            distanceKm: distanceKm,
            isFavorite: isFavorite,
            onFavoriteToggle: onFavoriteToggle,
          );
  }
}

// ── Wide / Featured card (vertical layout) ───────────────────────────────────

class _WideCard extends StatelessWidget {
  final GroundModel ground;
  final double? distanceKm;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const _WideCard({
    required this.ground,
    this.distanceKm,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imageUrl = ground.primaryImageUrl;
    final place = _placeLabel(ground, distanceKm);

    return AppAnimations.tapScale(
      onTap: () => context.push('/grounds/${ground.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        // The image is the flexible part, so a taller carousel slot grows the
        // photo instead of leaving a dead band under the text.
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _ImagePlaceholder(colors: colors),
                          errorWidget: (_, __, ___) =>
                              _ImagePlaceholder(colors: colors),
                        )
                      : _ImagePlaceholder(colors: colors),

                  // Scrim: the name and location below sit on whatever photo
                  // the owner uploaded, so they need their own ground.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x33000000),
                          Color(0x00000000),
                          Color(0xD9000000),
                        ],
                        stops: [0.0, 0.35, 1.0],
                      ),
                    ),
                  ),

                  if (ground.sportNames.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _OverlayPill(
                        // Every sport the venue offers. Showing only the first
                        // hid the reason most people pick a ground.
                        child: Text(
                          ground.sportNames
                              .map((n) => n.toUpperCase())
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onImage,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        if (ground.avgRating > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _RatingPill(rating: ground.avgRating),
                          ),
                        if (onFavoriteToggle != null)
                          _FavoriteButton(
                            isFavorite: isFavorite,
                            onTap: onFavoriteToggle!,
                          ),
                      ],
                    ),
                  ),

                  // Name + place, on the image where the scrim guarantees
                  // contrast in both themes.
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ground.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onImage,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (place != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 12, color: AppColors.onImage),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  place,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onImage,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer: fixed single row, so the card height stays predictable
            // inside the carousel whatever the ground has filled in.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  _PriceLabel(ground: ground),
                  const Spacer(),
                  // What is left today matters more than the amenity icons when
                  // the day is nearly gone, so it takes the slot when present.
                  if (ground.slotsLeftLabel != null)
                    Flexible(child: _SlotsLeftLabel(ground: ground))
                  else if (ground.amenities.isNotEmpty)
                    Flexible(
                      child: _AmenityStrip(ground: ground),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Normal / List card (horizontal layout) ───────────────────────────────────

class _HorizontalCard extends StatelessWidget {
  final GroundModel ground;
  final double? distanceKm;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const _HorizontalCard({
    required this.ground,
    this.distanceKm,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imageUrl = ground.primaryImageUrl;

    return AppAnimations.tapScale(
      onTap: () => context.push('/grounds/${ground.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail, with the distance sitting on it — the one number a
            // player scans a list for.
            SizedBox(
              width: 104,
              height: 104,
              // clipBehavior: the favourite's 44px hit box deliberately hangs
              // outside the thumbnail; hard-clipping it would swallow taps.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _ImagePlaceholder(
                                width: 104, height: 104, colors: colors),
                            errorWidget: (_, __, ___) => _ImagePlaceholder(
                                width: 104, height: 104, colors: colors),
                          )
                        : _ImagePlaceholder(
                            width: 104, height: 104, colors: colors),
                  ),
                  if (distanceKm != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _DistanceBadge(km: distanceKm!),
                    ),
                  if (onFavoriteToggle != null)
                    Positioned(
                      top: -7,
                      right: -7,
                      child: _FavoriteButton(
                        isFavorite: isFavorite,
                        onTap: onFavoriteToggle!,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (ground.sportNames.isNotEmpty)
                        Flexible(
                          child: _SportChip(name: ground.sportNames.join(' · ')),
                        ),
                      if (ground.avgRating > 0) ...[
                        const SizedBox(width: 6),
                        _RatingChip(rating: ground.avgRating),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ground.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((ground.city ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 12, color: colors.textSecondary),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            ground.city!,
                            style: TextStyle(
                                fontSize: 12, color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _PriceLabel(ground: ground),
                      const Spacer(),
                      if (ground.slotsLeftLabel != null)
                        Flexible(child: _SlotsLeftLabel(ground: ground)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared pieces ────────────────────────────────────────────────────────────

/// "Chennai · 3.2 km" — whichever halves we actually have.
String? _placeLabel(GroundModel ground, double? distanceKm) {
  final city = (ground.city ?? '').trim();
  final distance = distanceKm == null ? null : '${Geo.format(distanceKm)} away';
  if (city.isEmpty) return distance;
  if (distance == null) return city;
  return '$city · $distance';
}

/// Starting price. Reads as brand ink rather than the neon fill colour, which
/// is close to invisible on the light theme's white card.
class _PriceLabel extends StatelessWidget {
  final GroundModel ground;
  const _PriceLabel({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final price = ground.formattedStartingPrice;
    if (price == null) {
      return Text(
        'Price on request',
        style: TextStyle(fontSize: 12, color: colors.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            price,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.brandText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '/ slot',
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// The sport label on a list card. A tinted chip rather than grey micro-caps —
/// the old treatment was the least readable thing on the card.
/// "4 of 14 left today", or "Full today" when nothing is bookable.
///
/// Same wording as the venues list, so a ground reads identically wherever it
/// is shown. Colour is paired with the words, never used on its own.
class _SlotsLeftLabel extends StatelessWidget {
  final GroundModel ground;
  const _SlotsLeftLabel({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final full = ground.isFullyBookedToday;
    final label = full
        ? 'Full today'
        : (ground.slotsLeftLabel ?? '').replaceAll(' slots left', ' left');

    return Text(
      label,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: full ? colors.textSecondary : AppColors.primary,
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  final String name;
  const _SportChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          color: colors.brandText,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Rating on a card surface: amber star + the number, never colour alone.
class _RatingChip extends StatelessWidget {
  final double rating;
  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 11, color: AppColors.rating),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 10,
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rating over a photo — same content, scrim ground.
class _RatingPill extends StatelessWidget {
  final double rating;
  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    return _OverlayPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.star),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.onImage,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// How far the venue is from the user, over the thumbnail.
class _DistanceBadge extends StatelessWidget {
  final double km;
  const _DistanceBadge({required this.km});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${Geo.format(km)} away',
      excludeSemantics: true,
      child: _OverlayPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.near_me_rounded, size: 10, color: AppColors.onImage),
            const SizedBox(width: 3),
            Text(
              Geo.format(km),
              style: const TextStyle(
                color: AppColors.onImage,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A badge that sits on a ground photo. The scrim is what makes the label
/// readable over a bright image, which the old translucent-brand pill was not.
class _OverlayPill extends StatelessWidget {
  final Widget child;
  const _OverlayPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.imageScrim,
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

/// Up to two amenity names, on one line — the featured card's height is fixed
/// by the carousel and a second run would push the price out of it.
class _AmenityStrip extends StatelessWidget {
  final GroundModel ground;
  const _AmenityStrip({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: ground.amenities
          .take(2)
          .map((a) => Flexible(
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.input,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    a.name,
                    style: TextStyle(color: colors.textSecondary, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

/// Favourite toggle with a 44x44 hit area and a small visual circle, as the
/// touch-target rule requires. Shared by both card layouts.
class _FavoriteButton extends StatelessWidget {
  static const double _visualSize = 30;

  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteButton({required this.isFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isFavorite ? 'Remove from saved' : 'Save this ground',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: _visualSize,
              height: _visualSize,
              decoration: const BoxDecoration(
                color: AppColors.imageScrim,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: isFavorite ? AppColors.error : AppColors.onImage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final AppColors colors;
  const _ImagePlaceholder({this.width, this.height, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: colors.input,
      child: Center(
        child: Icon(Icons.sports_soccer, color: colors.border, size: 36),
      ),
    );
  }
}
