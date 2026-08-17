import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.fontSize = 11,
  });

  factory StatusBadge.bookingStatus(String status) {
    Color bg;
    Color text;
    switch (status.toLowerCase()) {
      case 'confirmed':
        bg = AppColors.primary.withValues(alpha: 0.15);
        text = AppColors.primary;
        break;
      case 'pending':
        bg = Colors.orange.withValues(alpha: 0.15);
        text = Colors.orange;
        break;
      case 'completed':
        bg = Colors.blue.withValues(alpha: 0.15);
        text = Colors.blue;
        break;
      case 'cancelled':
        bg = AppColors.error.withValues(alpha: 0.15);
        text = AppColors.error;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        text = Colors.grey;
    }
    return StatusBadge(label: status, color: bg, textColor: text);
  }

  factory StatusBadge.gameLevel(String level) {
    Color bg;
    switch (level.toLowerCase()) {
      case 'beginner':
        bg = AppColors.primary;
        break;
      case 'intermediate':
        bg = Colors.orange;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: textColor ?? AppColors.primary,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
