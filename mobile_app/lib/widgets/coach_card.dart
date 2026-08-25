import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_colors.dart';
import '../models/coach_model.dart';

class CoachCard extends StatelessWidget {
  final CoachModel coach;
  final VoidCallback? onTap;

  const CoachCard({super.key, required this.coach, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // Avatar with award badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: coach.photo != null
                      ? CachedNetworkImage(
                          imageUrl: coach.photo!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 72,
                            height: 72,
                            color: colors.input,
                            child:
                                Icon(Icons.person, color: colors.textSecondary),
                          ),
                          errorWidget: (_, __, ___) => _avatarFallback(colors),
                        )
                      : _avatarFallback(colors),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.emoji_events,
                        size: 12, color: AppColors.onAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coach.name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.star),
                      const SizedBox(width: 2),
                      Text(
                        '${coach.rating.toStringAsFixed(1)} (${coach.reviewCount})',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          coach.experienceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (coach.expertiseTags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: coach.expertiseTags
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  if (coach.locality != null && coach.locality!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 12, color: colors.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            coach.locality!,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
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
            // Price. A coach who has not set one reads as "Price on request",
            // never as ₹0 — which a customer reads as free.
            //
            // Width-capped because that copy is four times as wide as a ₹ figure
            // and this column does not flex: uncapped it pushed the row past the
            // card by 120px on a 412dp phone.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    coach.formattedRate,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: coach.isBookable ? 14 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (coach.isBookable)
                    Text(
                      coach.rateCaption,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10,
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

  Widget _avatarFallback(AppColors colors) => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            coach.name.isNotEmpty ? coach.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}
