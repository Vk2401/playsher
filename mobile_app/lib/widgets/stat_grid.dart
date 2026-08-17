import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class StatItem {
  final String label;
  final String value;
  final IconData? icon;

  const StatItem({required this.label, required this.value, this.icon});
}

class StatGrid extends StatelessWidget {
  final List<StatItem> stats;

  const StatGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: stats.asMap().entries.map((entry) {
          final i = entry.key;
          final stat = entry.value;
          return Expanded(
            child: Container(
              decoration: i < stats.length - 1
                  ? BoxDecoration(
                      border: Border(
                        right: BorderSide(color: colors.border),
                      ),
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stat.icon != null)
                    Icon(stat.icon, color: AppColors.accent, size: 20),
                  if (stat.icon != null) const SizedBox(height: 4),
                  Text(
                    stat.value,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.label,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
