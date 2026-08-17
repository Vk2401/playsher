import 'package:flutter/material.dart';

/// Shared animation utilities for the Playsher app.
class AppAnimations {
  /// Standard page transition: slide up + fade.
  static Widget slideUpFade(
    Animation<double> animation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }

  /// Card tap scale effect wrapper.
  static Widget tapScale({
    required Widget child,
    required VoidCallback? onTap,
    double pressedScale = 0.97,
  }) {
    return _TapScaleWidget(
      onTap: onTap,
      pressedScale: pressedScale,
      child: child,
    );
  }
}

class _TapScaleWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _TapScaleWidget({
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<_TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<_TapScaleWidget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
