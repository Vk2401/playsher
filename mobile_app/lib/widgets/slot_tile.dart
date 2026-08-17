import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/slot_model.dart';

class SlotTile extends StatelessWidget {
  final SlotModel slot;
  final bool selected;
  final String? category;
  final VoidCallback? onTap;

  const SlotTile({
    super.key,
    required this.slot,
    this.selected = false,
    this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final available = slot.isAvailable;
    final active = available && selected;

    return GestureDetector(
      onTap: available ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent
              : available
                  ? colors.input
                  : colors.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.accent : colors.border,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.formattedStart,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active
                    ? Colors.black
                    : available
                        ? colors.textPrimary
                        : colors.textSecondary,
              ),
            ),
            Text(
              '\u2013',
              style: TextStyle(
                fontSize: 10,
                color: active
                    ? Colors.black54
                    : colors.textSecondary,
              ),
            ),
            Text(
              slot.formattedEnd,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: active
                    ? Colors.black
                    : available
                        ? colors.textSecondary
                        : colors.border,
              ),
            ),
            if (!available)
              Text(
                'Booked',
                style: TextStyle(
                    fontSize: 9, color: colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
