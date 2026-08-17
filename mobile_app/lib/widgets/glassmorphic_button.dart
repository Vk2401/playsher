import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphicButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double blur;
  final Color? color;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  const GlassmorphicButton({
    super.key,
    this.onTap,
    required this.child,
    this.blur = 10,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Material(
          color: color ?? Colors.white.withValues(alpha: 0.15),
          borderRadius: borderRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
