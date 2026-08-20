import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final double fontSize;

  /// Paired with [color] so the state is still distinguishable in greyscale
  /// or by a colour-blind player — never signal status by fill alone.
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.fontSize = 11,
    this.icon,
  });

  factory StatusBadge.bookingStatus(String status) {
    Color bg;
    Color text;
    IconData glyph;
    switch (status.toLowerCase()) {
      case 'confirmed':
        bg = AppColors.primary.withValues(alpha: 0.15);
        text = AppColors.primary;
        glyph = Icons.check_circle_rounded;
        break;
      case 'pending':
        bg = AppColors.warning.withValues(alpha: 0.15);
        text = AppColors.warning;
        glyph = Icons.schedule_rounded;
        break;
      case 'completed':
        bg = AppColors.info.withValues(alpha: 0.15);
        text = AppColors.info;
        glyph = Icons.done_all_rounded;
        break;
      case 'cancelled':
        bg = AppColors.error.withValues(alpha: 0.15);
        text = AppColors.error;
        glyph = Icons.cancel_rounded;
        break;
      default:
        bg = AppColors.neutral.withValues(alpha: 0.15);
        text = AppColors.neutral;
        glyph = Icons.info_outline_rounded;
    }
    return StatusBadge(label: status, color: bg, textColor: text, icon: glyph);
  }

  factory StatusBadge.gameLevel(String level) {
    Color bg;
    switch (level.toLowerCase()) {
      case 'beginner':
        bg = AppColors.primary;
        break;
      case 'intermediate':
        bg = AppColors.warning;
        break;
      case 'advanced':
        bg = AppColors.error;
        break;
      default:
        bg = AppColors.accent;
    }
    return StatusBadge(
      label: level,
      color: bg.withValues(alpha: 0.15),
      textColor: bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
