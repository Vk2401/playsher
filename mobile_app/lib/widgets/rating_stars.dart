import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool showLabel;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 14,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            if (i < rating.floor()) {
              return Icon(Icons.star_rounded,
                  color: AppColors.star, size: size);
            } else if (i < rating) {
              return Icon(Icons.star_half_rounded,
                  color: AppColors.star, size: size);
            }
            return Icon(Icons.star_outline_rounded,
                color: colors.border, size: size);
          }),
        ),
        if (showLabel && rating > 0) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size - 1,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}
