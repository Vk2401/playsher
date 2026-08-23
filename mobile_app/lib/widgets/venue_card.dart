import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/animations.dart';
import '../core/app_colors.dart';
import '../models/ground_model.dart';
import 'favorite_button.dart';
import '../models/weather_model.dart';
import 'sport_glyph.dart';

/// A venue in the explore list.
///
/// Answers, without opening it: where it is, what it costs per slot, what is
/// still bookable today, whether it is covered, and how far away it is. The
/// previous card showed a name and "Price on request", which is not enough to
/// choose between two grounds.
class VenueCard extends StatelessWidget {
  final GroundModel ground;

  /// Conditions at this venue right now, when they are known. Null hides the
  /// chip entirely — weather is a nicety and never worth an error state.
  final Weather? weather;

  const VenueCard({super.key, required this.ground, this.weather});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sports = ground.sportNames;

    return AppAnimations.tapScale(
      onTap: () => context.push('/grounds/${ground.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumb(ground: ground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                ground.name,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ground.reviewCount > 0) ...[
                              const SizedBox(width: 8),
                              _Rating(ground: ground),
                            ],
                            // In the title row rather than over the thumbnail:
                            // an 84px picture cannot carry a 44px target
                            // without becoming the target.
                            FavoriteButton(
                              ground: ground,
                              tone: FavoriteButtonTone.onSurface,
                              visualSize: 20,
                            ),
                          ],
                        ),

                        // Where it is — the first thing a player checks.
                        if (ground.locality != null) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 13, color: colors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  ground.formattedDistance == null
                                      ? ground.locality!
                                      : '${ground.locality!}  ·  ${ground.formattedDistance}',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: colors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (sports.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SportRow(sports: sports),
                        ],

                        if (weather != null) ...[
                          const SizedBox(height: 8),
                          _WeatherChip(
                            weather: weather!,
                            hasRoof: ground.hasRoof,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer: price and what is left today ───────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: 0.04),
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                children: [
                  Expanded(child: _Price(ground: ground)),
                  const SizedBox(width: 8),
                  _SlotsLeft(ground: ground),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final GroundModel ground;
  const _Thumb({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = ground.primaryImageUrl;

    Widget fallback() => Container(
          width: 84,
          height: 84,
          color: colors.card,
          child: Center(
            child: SportGlyph(
              name: ground.sportNames.isEmpty ? '' : ground.sportNames.first,
              size: 30,
            ),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: url == null || url.isEmpty
                ? fallback()
                : CachedNetworkImage(
                    imageUrl: url,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => fallback(),
                    errorWidget: (_, __, ___) => fallback(),
                  ),
          ),
          // Covered venues are worth calling out — it is the difference
          // between playing and not, half the year.
          if (ground.hasRoof)
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.roofing_rounded,
                        size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Covered',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  final GroundModel ground;
  const _Rating({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppColors.star),
          const SizedBox(width: 3),
          Text(
            ground.avgRating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SportRow extends StatelessWidget {
  final List<String> sports;
  const _SportRow({required this.sports});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Three names plus a count, rather than a row that wraps to three lines on
    // a multi-sport complex.
    final shown = sports.take(3).toList();
    final extra = sports.length - shown.length;

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        ...shown.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s,
                style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
              ),
            )),
        if (extra > 0)
          Text('+$extra',
              style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
      ],
    );
  }
}

class _Price extends StatelessWidget {
  final GroundModel ground;
  const _Price({required this.ground});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final price = ground.formattedStartingPrice;

    // "Price on request" is what the card showed for every ground while the
    // API was omitting sports. It is now the honest answer only when the owner
    // genuinely has not priced the venue.
    if (price == null) {
      return Text(
        'Price on request',
        style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: price,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          TextSpan(
            text: ' / slot',
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SlotsLeft extends StatelessWidget {
  final GroundModel ground;
  const _SlotsLeft({required this.ground});

  @override
  Widget build(BuildContext context) {
    final left = ground.slotsAvailableToday;
    final total = ground.slotsTotalToday;

    // Absent when the day has not been generated. Showing "0 of 0" there would
    // read as "fully booked" for a venue nobody has opened yet.
    if (left == null || total == null || total == 0) {
      return const SizedBox.shrink();
    }

    final full = left == 0;
    final tight = !full && left <= 3;
    final tone = full
        ? AppColors.error
        : tight
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Never state alone by colour: the words carry the meaning too.
          Icon(full ? Icons.block_rounded : Icons.bolt_rounded,
              size: 12, color: tone),
          const SizedBox(width: 4),
          Text(
            full ? 'Full today' : '$left of $total left today',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Conditions at the venue.
///
/// Rain matters far more at an uncovered ground than a covered one, so the
/// chip escalates only there — under a roof it stays a plain temperature.
class _WeatherChip extends StatelessWidget {
  final Weather weather;
  final bool hasRoof;

  const _WeatherChip({required this.weather, required this.hasRoof});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final warn = weather.isWet && !hasRoof;

    final tone = warn ? AppColors.warning : colors.textSecondary;
    final label = warn
        ? '${weather.description} — uncovered'
        : '${weather.temperatureLabel}  ·  ${weather.description}';

    return Row(
      children: [
        Icon(
          warn ? Icons.umbrella_rounded : _icon(weather.code),
          size: 13,
          color: tone,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: warn ? FontWeight.w700 : FontWeight.w400,
              color: tone,
            ),
          ),
        ),
      ],
    );
  }

  static IconData _icon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
    if (code >= 71 && code <= 86) return Icons.ac_unit_rounded;
    return Icons.water_drop_rounded;
  }
}
