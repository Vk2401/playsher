import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'splash_stage.dart';

/// The picture at the top of the location screen: a map pin standing on a
/// street plan, with a city behind it and a ground seen through its window.
///
/// Painted, like the stadium and the sports props, so it costs a few hundred
/// bytes instead of a megabyte and follows the device theme instead of being a
/// light-mode bitmap on a dark page. The ground inside the pin is the real
/// [SplashStage] clipped to a circle rather than a drawing of one — the pin
/// literally frames the place the app is about to find for you.
class LocationHero extends StatelessWidget {
  const LocationHero({super.key});

  /// Height as a fraction of the width the hero is given.
  static const _aspect = 0.56;

  @override
  Widget build(BuildContext context) {
    final frame = context.frame;

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w * _aspect;
          final geometry = _HeroGeometry(w, h);

          return SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                // The city, the plan it stands on, and the pin's body.
                Positioned.fill(
                  child: CustomPaint(painter: _HeroPainter(frame, geometry)),
                ),

                // The ground, seen through the pin.
                Positioned(
                  left: geometry.head.dx - geometry.windowRadius,
                  top: geometry.head.dy - geometry.windowRadius,
                  width: geometry.windowRadius * 2,
                  height: geometry.windowRadius * 2,
                  child: _WindowOnAGround(diameter: geometry.windowRadius * 2),
                ),

                // The rim that holds it, over the picture's edge.
                Positioned.fill(
                  child: CustomPaint(painter: _RimPainter(geometry)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The stadium, framed by the pin rather than merely clipped by it.
///
/// [SplashStage] composes for a whole phone: two thirds of it is sky, with the
/// horizon at 63% of the height. Dropped into a circle at that scale the pin
/// shows mostly weather, so the ground is laid out larger than the window and
/// lifted until the turf — the part that says "a place to play" — fills the
/// lower half, the way the design frames it.
class _WindowOnAGround extends StatelessWidget {
  const _WindowOnAGround({required this.diameter});

  final double diameter;

  /// Where the horizon should land inside the window.
  static const _horizonAt = 0.38;

  /// How much bigger than the window the ground is drawn.
  static const _scale = (width: 1.45, height: 1.65);

  /// [SplashStage]'s own horizon, as a fraction of its height.
  static const _stageHorizon = 0.63;

  @override
  Widget build(BuildContext context) {
    final height = diameter * _scale.height;
    final lift = _horizonAt * diameter - _stageHorizon * height;

    return ClipOval(
      child: OverflowBox(
        maxWidth: diameter * _scale.width,
        maxHeight: height,
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: Offset(0, lift),
          child: SizedBox(
            width: diameter * _scale.width,
            height: height,
            child: const SplashStage(),
          ),
        ),
      ),
    );
  }
}

/// Where each piece sits, resolved once so the painters and the clipped
/// stadium cannot drift apart.
class _HeroGeometry {
  _HeroGeometry(this.w, this.h);

  final double w;
  final double h;

  /// The centre of the pin's head, and how big its window is.
  Offset get head => Offset(w * 0.5, h * 0.36);
  double get headRadius => w * 0.155;
  double get windowRadius => headRadius * 0.70;

  /// Where the pin touches the plan.
  Offset get tip => Offset(w * 0.5, h * 0.845);

  /// The street plan, as a flat card seen slightly from above.
  Rect get plan => Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.86),
        width: w * 0.60,
        height: h * 0.30,
      );
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter(this.palette, this.g);

  final FramePalette palette;
  final _HeroGeometry g;

  @override
  void paint(Canvas canvas, Size size) {
    _skyline(canvas);
    _plan(canvas);
    _minorPin(canvas, Offset(g.w * 0.29, g.h * 0.58), g.w * 0.045,
        AppColors.success);
    _minorPin(canvas, Offset(g.w * 0.72, g.h * 0.62), g.w * 0.038,
        AppColors.primary);
    _pin(canvas);
  }

  /// A city, far enough back to be weather rather than subject.
  void _skyline(Canvas canvas) {
    final base = g.h * 0.66;
    final paint = Paint()..color = palette.standLight.withValues(alpha: 0.16);

    // Heights chosen to read as a skyline rather than a bar chart: a tall
    // pair off-centre, shorter blocks running out to both edges.
    const blocks = <(double, double, double)>[
      (0.02, 0.10, 0.30),
      (0.11, 0.09, 0.44),
      (0.19, 0.11, 0.26),
      (0.29, 0.08, 0.36),
      (0.60, 0.10, 0.40),
      (0.69, 0.12, 0.52),
      (0.80, 0.09, 0.32),
      (0.88, 0.11, 0.42),
    ];

    for (final (x, width, height) in blocks) {
      final rect = Rect.fromLTWH(
        g.w * x,
        base - g.h * height,
        g.w * width,
        g.h * height,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(g.w * 0.012),
          topRight: Radius.circular(g.w * 0.012),
        ),
        paint,
      );

      // Windows, as one lighter band per floor rather than a grid of squares:
      // at this size a grid turns to noise.
      final floors = (rect.height / (g.h * 0.055)).floor();
      for (var i = 1; i < floors; i++) {
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + rect.width * 0.18,
            rect.top + i * (g.h * 0.055),
            rect.width * 0.64,
            g.h * 0.012,
          ),
          Paint()..color = palette.page.withValues(alpha: 0.55),
        );
      }
    }
  }

  /// The street plan the pin stands on.
  void _plan(Canvas canvas) {
    final r = g.plan;
    final radius = Radius.circular(r.height * 0.24);
    final body = RRect.fromRectAndRadius(r, radius);

    // The card's thickness, drawn as a second body slipped down behind it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.translate(0, r.height * 0.13), radius),
      Paint()..color = palette.standLight.withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      body,
      Paint()..color = palette.standLight.withValues(alpha: 0.22),
    );

    canvas.save();
    canvas.clipRRect(body);

    // Blocks of green between the roads — parks, the reason a map of a city
    // is not just grey.
    final park = Paint()..color = palette.turfMid.withValues(alpha: 0.45);
    canvas.drawRect(
      Rect.fromLTWH(r.left + r.width * 0.08, r.top + r.height * 0.14,
          r.width * 0.20, r.height * 0.30),
      park,
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left + r.width * 0.62, r.top + r.height * 0.52,
          r.width * 0.26, r.height * 0.34),
      park,
    );

    final road = Paint()..color = palette.page.withValues(alpha: 0.75);
    for (final x in [0.30, 0.56, 0.82]) {
      canvas.drawRect(
        Rect.fromLTWH(r.left + r.width * x, r.top, r.width * 0.045, r.height),
        road,
      );
    }
    for (final y in [0.30, 0.66]) {
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top + r.height * y, r.width, r.height * 0.075),
        road,
      );
    }
    canvas.restore();

    // What the pin casts on the plan — the only thing that makes it read as
    // standing on the card rather than floating over it.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(g.tip.dx, g.tip.dy - r.height * 0.04),
        width: g.headRadius * 1.5,
        height: g.headRadius * 0.42,
      ),
      Paint()
        ..color = AppColors.shieldDeep.withValues(alpha: 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, g.headRadius * 0.16),
    );
  }

  /// The pin itself: a head, two flanks falling to a point.
  void _pin(Canvas canvas) {
    final c = g.head;
    final r = g.headRadius;
    final path = Path()..moveTo(g.tip.dx, g.tip.dy);

    // Up the left flank to the head, round the top, and back down the right.
    path.quadraticBezierTo(
        c.dx - r * 0.62, c.dy + r * 1.05, c.dx - r * 0.87, c.dy + r * 0.50);
    path.arcToPoint(
      Offset(c.dx + r * 0.87, c.dy + r * 0.50),
      radius: Radius.circular(r),
      largeArc: true,
    );
    path.quadraticBezierTo(
        c.dx + r * 0.62, c.dy + r * 1.05, g.tip.dx, g.tip.dy);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r, c.dy - r),
          Offset(c.dx + r, g.tip.dy),
          [AppColors.shieldLight, AppColors.primary, AppColors.shieldDeep],
          [0.0, 0.45, 1.0],
        ),
    );

    // The lip around the window, which is what gives the head its depth.
    canvas.drawCircle(
      c,
      (g.windowRadius + r) / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r - g.windowRadius
        ..shader = ui.Gradient.linear(
          Offset(c.dx - r, c.dy - r),
          Offset(c.dx + r, c.dy + r),
          [
            AppColors.shieldLight.withValues(alpha: 0.85),
            AppColors.shieldDeep.withValues(alpha: 0.55),
          ],
        ),
    );
  }

  /// One of the other grounds on the map, small and unlabelled.
  void _minorPin(Canvas canvas, Offset centre, double r, Color color) {
    final tip = Offset(centre.dx, centre.dy + r * 2.4);
    final path = Path()..moveTo(tip.dx, tip.dy);
    path.quadraticBezierTo(
        centre.dx - r * 0.6, centre.dy + r * 1.05, centre.dx - r * 0.87,
        centre.dy + r * 0.5);
    path.arcToPoint(
      Offset(centre.dx + r * 0.87, centre.dy + r * 0.5),
      radius: Radius.circular(r),
      largeArc: true,
    );
    path.quadraticBezierTo(
        centre.dx + r * 0.6, centre.dy + r * 1.05, tip.dx, tip.dy);
    path.close();

    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));
    canvas.drawCircle(
        centre, r * 0.38, Paint()..color = palette.page.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.palette != palette;
}

/// The rim, painted after the ground so it sits over the picture's edge
/// instead of under it.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.g);

  final _HeroGeometry g;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      g.head,
      g.windowRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = g.windowRadius * 0.09
        ..color = AppColors.shieldDeep.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) => false;
}
