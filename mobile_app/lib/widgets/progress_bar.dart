import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class ProgressBar extends StatelessWidget {
  final double value;
  final String? label;
  final double height;
  final Color? activeColor;
  final Color? backgroundColor;

  const ProgressBar({
    super.key,
    required this.value,
    this.label,
    this.height = 6,
    this.activeColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clamped = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: height,
            backgroundColor: backgroundColor ?? colors.border,
            valueColor: AlwaysStoppedAnimation(
              activeColor ??
                  (clamped > 0.8 ? AppColors.error : AppColors.primary),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
