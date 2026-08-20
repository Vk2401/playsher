import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Slot tile with diagonal stripe pattern for booked slots.
class StripedSlotTile extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool isBooked;
  final bool isSelected;
  final bool isAvailable;
  final String? category;
  final VoidCallback? onTap;

  const StripedSlotTile({
    super.key,
    required this.label,
    this.sublabel,
    this.isBooked = false,
    this.isSelected = false,
    this.isAvailable = true,
    this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Color bgColor;
    Color textColor;
    if (isSelected) {
      bgColor = AppColors.accent;
      textColor = AppColors.onPrimary;
    } else if (isBooked || !isAvailable) {
      bgColor = colors.border.withValues(alpha: 0.3);
      textColor = colors.textSecondary;
    } else {
      bgColor = colors.input;
      textColor = colors.textPrimary;
    }

    return GestureDetector(
      onTap: (isBooked || !isAvailable) ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : colors.border,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              if (isBooked || !isAvailable)
                Positioned.fill(
                  child: CustomPaint(painter: _StripePainter(colors.border)),
                ),
              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (sublabel != null)
                        Text(
                          sublabel!,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (isBooked) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Booked',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  _StripePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 8.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
