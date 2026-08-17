import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';

import '../models/ground_model.dart';

class GroundCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return wide
        ? _WideCard(
            ground: ground,
            isFavorite: isFavorite,
            onFavoriteToggle: onFavoriteToggle,
          )
        : _HorizontalCard(
            ground: ground,
            isFavorite: isFavorite,
            onFavoriteToggle: onFavoriteToggle,
          );
  }
}

// ── Wide / Featured card (vertical layout) ───────────────────────────────────

class _WideCard extends StatelessWidget {
  final GroundModel ground;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const _WideCard({
    required this.ground,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imageUrl = ground.primaryImageUrl;

    return GestureDetector(
      onTap: () => context.push('/grounds/${ground.id}'),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlays
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 156,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              _ImagePlaceholder(height: 156, colors: colors),
                          errorWidget: (_, __, ___) =>
                              _ImagePlaceholder(height: 156, colors: colors),
                        )
                      : _ImagePlaceholder(height: 156, colors: colors),

                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Category badge top-left
                  if (ground.sportNames.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          ground.sportNames.first.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),

                  // Heart toggle top-right
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      children: [
                        if (ground.avgRating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 12, color: Colors.black),
                                const SizedBox(width: 2),
                                Text(
                                  ground.avgRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (onFavoriteToggle != null)
                          GestureDetector(
                            onTap: onFavoriteToggle,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color:
                                    Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 16,
                                color: isFavorite
                                    ? AppColors.error
                                    : Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ground.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if ((ground.city ?? '').isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 12, color: colors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          ground.city!,
                          style: TextStyle(
                              fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  // Amenity tags
                  if (ground.amenities.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: ground.amenities
                          .take(3)
                          .map((a) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.input,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  a.name,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 9,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  if (ground.amenities.isNotEmpty) const SizedBox(height: 6),
                  if (ground.startingPrice > 0)
                    Text(
                      ground.formattedStartingPrice,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
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
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const _HorizontalCard({
    required this.ground,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final imageUrl = ground.primaryImageUrl;

    return GestureDetector(
      onTap: () => context.push('/grounds/${ground.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // Thumbnail with heart overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _ImagePlaceholder(
                              width: 112, height: 112, colors: colors),
                          errorWidget: (_, __, ___) => _ImagePlaceholder(
                              width: 112, height: 112, colors: colors),
                        )
                      : _ImagePlaceholder(
                          width: 112, height: 112, colors: colors),
                ),
                if (onFavoriteToggle != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 14,
                          color:
                              isFavorite ? AppColors.error : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ground.sportNames.isNotEmpty)
                    Text(
                      ground.sportNames.first.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    ground.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if ((ground.city ?? '').isNotEmpty)
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (ground.avgRating > 0) ...[
                        const Icon(Icons.star_rounded,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          ground.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (ground.startingPrice > 0)
                        Text(
                          ground.formattedStartingPrice,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
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

class _ImagePlaceholder extends StatelessWidget {
  final double? width;
  final double height;
  final AppColors colors;
  const _ImagePlaceholder({this.width, required this.height, required this.colors});

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
