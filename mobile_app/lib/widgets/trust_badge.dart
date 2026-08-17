import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const TrustBadge({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
  });

  factory TrustBadge.verified() => const TrustBadge(
        icon: Icons.verified,
        label: 'Verified Venue',
        iconColor: AppColors.primary,
      );

  factory TrustBadge.quality() => const TrustBadge(
        icon: Icons.shield,
        label: 'Quality Training',
        iconColor: Colors.blue,
      );

  factory TrustBadge.certified() => const TrustBadge(
        icon: Icons.workspace_premium,
        label: 'Certified Coach',
        iconColor: AppColors.accent,
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iColor = iconColor ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: iColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
