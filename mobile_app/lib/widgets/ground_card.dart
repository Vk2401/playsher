import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/animations.dart';
import '../core/app_colors.dart';
import '../core/geo.dart';
import '../models/ground_model.dart';
import '../providers/location_provider.dart';
import 'favorite_button.dart';

/// A ground, in the two shapes the app uses: a wide card for the featured
/// carousel and a horizontal row for every list.
///
/// It reads the user's position itself rather than taking a distance prop, so
/// that every list in the app gains "how far away" without each screen having
/// to thread it through.
class GroundCard extends ConsumerWidget {
  final GroundModel ground;
  final bool wide;
  /// Whether to draw the save control. On by default: a ground card without
  /// a heart is the odd one out, not the norm.
  final bool showFavorite;

  /// Shows a "Book Now" button on the list card. Off by default so a dense
  /// list stays dense; the home screen turns it on for the handful of venues
  /// it puts under "Nearest to you", where the tap is the point.
  final bool showBookAction;

  const GroundCard({
    super.key,
    required this.ground,
    this.wide = false,
    this.showFavorite = true,
    this.showBookAction = false,
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
            showFavorite: showFavorite,
          )
        : _HorizontalCard(
            ground: ground,
            distanceKm: distanceKm,
            showFavorite: showFavorite,
            showBookAction: showBookAction,
          );
  }
}

// ── Wide / Featured card (vertical layout) ───────────────────────────────────

class _WideCard extends StatelessWidget {
  final GroundModel ground;
  final double? distanceKm;
  final bool showFavorite;

  const _WideCard({
    required this.ground,
    this.distanceKm,
    this.showFavorite = true,
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
          boxShadow: _cardShadow,
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
                      top: 12,
                      left: 12,
                      // Only reserved when there is something in the top-right
                      // corner to run into; without it the badge was clipping
                      // "BASKETBALL" for no reason.
                      right: (showFavorite ? 50 : 0) +
                          (ground.avgRating > 0 ? 56 : 0) +
                          12,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _SportPill(sports: ground.sportNames),
                      ),
                    ),

                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      children: [
                        if (ground.avgRating > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _RatingPill(rating: ground.avgRating),
                          ),
                        if (showFavorite) FavoriteButton(ground: ground),
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
                            fontSize: 17,
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
                                  size: 13, color: AppColors.onImage),
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
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  _PriceLabel(ground: ground),
                  const Spacer(),
                  // What is left today matters more than the amenity icons when
                  // the day is nearly gone, so it takes the slot when present.
                  if (ground.slotsLeftLabel != null)
                    Flexible(
                        child: _SlotsLeftLabel(ground: ground, compact: true))
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
  final bool showFavorite;
  final bool showBookAction;

  const _HorizontalCard({
    required this.ground,
    this.distanceKm,
    this.showFavorite = true,
    this.showBookAction = false,
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
          boxShadow: _cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail, with the distance sitting on it — the one number a
            // player scans a list for.
            SizedBox(
              width: 104,
              height: 112,
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
                            height: 112,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _ImagePlaceholder(
                                width: 104, height: 112, colors: colors),
                            errorWidget: (_, __, ___) => _ImagePlaceholder(
                                width: 104, height: 112, colors: colors),
                          )
                        : _ImagePlaceholder(
                            width: 104, height: 112, colors: colors),
                  ),
                  if (distanceKm != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _DistanceBadge(km: distanceKm!),
                    ),
                  if (showFavorite)
                    Positioned(
                      top: -7,
                      right: -7,
                      child: FavoriteButton(ground: ground),
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
                  if (ground.sportNames.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _SportChip(name: ground.sportNames.join(' · ')),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    ground.name,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // Rating and what is left today share a line: the two numbers
                  // a player weighs against each other before tapping.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (ground.avgRating > 0)
                        Flexible(
                          child: _RatingRow(
                            rating: ground.avgRating,
                            reviewCount: ground.reviewCount,
                          ),
                        )
                      else if ((ground.city ?? '').isNotEmpty)
                        Flexible(
                          child: Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 12, color: colors.textSecondary),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  ground.city!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (ground.slotsLeftLabel != null) ...[
                        const SizedBox(width: 8),
                        Flexible(child: _SlotsLeftLabel(ground: ground)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Expanded, not Flexible: the price keeps the left edge
                      // and hands the rest of the row to the button, so every
                      // card's Book Now lands on the same right margin.
                      Expanded(child: _PriceLabel(ground: ground)),
                      if (showBookAction) ...[
                        const SizedBox(width: 8),
                        _BookButton(ground: ground),
                      ],
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

/// The lift under every venue card. Invisible on the dark theme, where
/// [AppColors.dark.border] is what separates a card from the background — which
/// is why both are set, not one or the other.
final List<BoxShadow> _cardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 12,
    offset: const Offset(0, 3),
  ),
];

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

/// Every sport the venue offers, on the photo, filled with the first one's
/// colour. A venue is scanned for its sport before its name, and a solid pill
/// is legible over a bright photo where a translucent one is not.
class _SportPill extends StatelessWidget {
  final List<String> sports;
  const _SportPill({required this.sports});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sportTint(sports.first),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        sports.map((n) => n.toUpperCase()).join(' \u00b7 '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // Small and tight on purpose: a venue offering two sports has to fit
        // both names beside the favourite button on a 390pt phone.
        style: const TextStyle(
          color: AppColors.onImage,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// "4.6 (128 reviews)" — the star is amber so the rating reads on a white
/// card, and the count is what tells the user whether to trust the number.
class _RatingRow extends StatelessWidget {
  final double rating;
  final int reviewCount;

  const _RatingRow({required this.rating, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: reviewCount > 0
          ? 'Rated ${rating.toStringAsFixed(1)} out of 5 from $reviewCount reviews'
          : 'Rated ${rating.toStringAsFixed(1)} out of 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 15, color: AppColors.rating),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          if (reviewCount > 0) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                reviewCount == 1 ? '(1 review)' : '($reviewCount reviews)',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The list card's call to action. It lands on the venue, which is where slots
/// and the date live — the button is a shortcut into booking, not a booking.
class _BookButton extends StatelessWidget {
  final GroundModel ground;
  const _BookButton({required this.ground});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: () => context.push('/grounds/${ground.id}'),
        style: TextButton.styleFrom(
          minimumSize: const Size(104, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Book Now',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// "4 of 14 left today", or "Full today" when nothing is bookable.
///
/// Same wording as the venues list, so a ground reads identically wherever it
/// is shown. Colour is paired with the words, never used on its own.
class _SlotsLeftLabel extends StatelessWidget {
  final GroundModel ground;

  /// Drops "today" — the featured card's footer is half a screen wide and the
  /// full sentence was ellipsing to "18 of 18 le…", which says nothing.
  final bool compact;

  const _SlotsLeftLabel({required this.ground, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final full = ground.isFullyBookedToday;
    final label = full
        ? (compact ? 'Full' : 'Full today')
        : (ground.slotsLeftLabel ?? '')
            .replaceAll(' slots left today', compact ? ' left' : ' left today');

    return Text(
      label,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: full ? colors.textSecondary : colors.successText,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
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
