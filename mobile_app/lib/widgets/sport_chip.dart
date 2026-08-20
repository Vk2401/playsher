import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'sport_glyph.dart';

class SportChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback? onTap;

  /// Icon served by the Sports API for this sport. When null (or it fails to
  /// load) the chip falls back to [emoji].
  final String? imageUrl;

  const SportChip({
    super.key,
    required this.label,
    this.emoji,
    this.selected = false,
    this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : colors.input,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : colors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null || emoji != null) ...[
              SportGlyph(name: label, imageUrl: imageUrl, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.onPrimary : colors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
