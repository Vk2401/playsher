import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// A piece of sports equipment, painted.
///
/// The football on the login page is a photograph; everything beside it is
/// painted, because a scatter of props is flat gradients and a few arcs — a few
/// hundred bytes each against a megabyte of render per item, and each one
/// resizes to whatever corner it is tucked into without a crop.
enum SportProp { basketball, cricketBall, tennisBall, volleyball, cricketBat }

/// One prop at a given size.
///
/// Decoration: it carries no semantics and never takes a tap. On the dark page
/// the whole thing is dimmed rather than recoloured — real equipment keeps its
/// colour in the dark, it just catches less light.
class SportPropIcon extends StatelessWidget {
  const SportPropIcon(this.prop, {super.key, required this.size, this.turns = 0});

  final SportProp prop;

  /// Width in logical pixels; the bat is taller than it is wide.
  final double size;

  /// Rotation in turns, clockwise.
  final double turns;

  @override
  Widget build(BuildContext context) {
    final aspect = prop == SportProp.cricketBat ? 3.1 : 1.0;

    return ExcludeSemantics(
      child: IgnorePointer(
        child: Opacity(
          opacity: context.isDark ? 0.55 : 0.92,
          child: Transform.rotate(
            angle: turns * 2 * math.pi,
            child: CustomPaint(
              size: Size(size, size * aspect),
              painter: _PropPainter(prop),
            ),
          ),
        ),
      ),
    );
  }
}

class _PropPainter extends CustomPainter {
  const _PropPainter(this.prop);

  final SportProp prop;

  @override
  void paint(Canvas canvas, Size size) {
    switch (prop) {
      case SportProp.basketball:
        _basketball(canvas, size);
      case SportProp.cricketBall:
        _cricketBall(canvas, size);
      case SportProp.tennisBall:
        _tennisBall(canvas, size);
      case SportProp.volleyball:
        _volleyball(canvas, size);
      case SportProp.cricketBat:
        _cricketBat(canvas, size);
    }
  }

  /// The shared body every ball is built on: a lit sphere.
  ///
  /// One radial gradient off the upper-left for the form, a blurred specular
  /// blob for the gloss, and a darkened rim so the silhouette does not read as
  /// a flat disc.
  Rect _sphere(Canvas canvas, Size size, Color base) {
    final box = Rect.fromLTWH(0, 0, size.width, size.width);
    final centre = box.center;
    final radius = size.width / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          centre + Offset(-radius * 0.34, -radius * 0.38),
          radius * 1.45,
          [
            Color.lerp(base, Colors.white, 0.42)!,
            base,
            Color.lerp(base, Colors.black, 0.34)!,
          ],
          [0.0, 0.52, 1.0],
        ),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: centre + Offset(-radius * 0.36, -radius * 0.44),
        width: radius * 0.62,
        height: radius * 0.44,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.14),
    );

    return box;
  }

  /// Clips to the ball so a seam drawn as a full ellipse cannot escape it.
  void _onSphere(Canvas canvas, Rect box, void Function(Canvas) draw) {
    canvas.save();
    canvas.clipPath(Path()..addOval(box));
    draw(canvas);
    canvas.restore();
  }

  void _basketball(Canvas canvas, Size size) {
    final box = _sphere(canvas, size, AppColors.propBasketball);
    final r = box.width / 2;
    final c = box.center;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.085
      ..color = AppColors.propBasketballLine.withValues(alpha: 0.85);

    _onSphere(canvas, box, (canvas) {
      // Meridian and equator, then the two arcs that curve away round the back.
      canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 0.72, height: r * 2), line);
      canvas.drawLine(Offset(box.left, c.dy), Offset(box.right, c.dy), line);
      // The two side seams. Each is a whole oval pushed far enough across that
      // only its near arc lands inside the ball — the clip does the drawing,
      // so the seam bows outward the way a real one does without arc maths.
      for (final dir in [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
              center: c + Offset(-dir * r * 0.38, 0),
              width: r * 2.24,
              height: r * 2.3),
          line,
        );
      }
    });
  }

  void _cricketBall(Canvas canvas, Size size) {
    final box = _sphere(canvas, size, AppColors.propCricket);
    final r = box.width / 2;
    final c = box.center;

    _onSphere(canvas, box, (canvas) {
      // One seam, not a closed ellipse: a cricket ball shows a single curve
      // from this angle. Same trick as the basketball's side seams — the oval
      // is pushed across so only its near arc is inside the ball.
      final a = r * 1.22;
      final b = r * 1.12;
      final origin = Offset(c.dx - r * 0.56, c.dy);

      canvas.drawOval(
        Rect.fromCenter(center: origin, width: a * 2, height: b * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05
          ..color = AppColors.propCricketSeam.withValues(alpha: 0.85),
      );

      // The stitching: ticks stepped along the seam, laid across it.
      final stitch = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round
        ..color = AppColors.propCricketSeam;
      for (var i = -6; i <= 6; i++) {
        final t = i * 0.16;
        final dir = Offset(math.cos(t), math.sin(t));
        final on = origin + Offset(dir.dx * a, dir.dy * b);
        canvas.drawLine(on - dir * (r * 0.11), on + dir * (r * 0.11), stitch);
      }
    });
  }

  void _tennisBall(Canvas canvas, Size size) {
    final box = _sphere(canvas, size, AppColors.propTennis);
    final r = box.width / 2;
    final c = box.center;
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..color = AppColors.propTennisSeam.withValues(alpha: 0.95);

    _onSphere(canvas, box, (canvas) {
      // The two felt seams: mirrored arcs whose centres sit outside the ball.
      for (final dir in [-1.0, 1.0]) {
        canvas.drawArc(
          Rect.fromCenter(
              center: c + Offset(dir * r * 1.25, 0),
              width: r * 2.0,
              height: r * 2.3),
          dir > 0 ? math.pi * 0.60 : -math.pi * 0.40,
          math.pi * 0.80,
          false,
          seam,
        );
      }
    });
  }

  void _volleyball(Canvas canvas, Size size) {
    final box = _sphere(canvas, size, AppColors.propVolley);
    final r = box.width / 2;
    final c = box.center;
    final panel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..color = AppColors.propVolleyPanel;

    _onSphere(canvas, box, (canvas) {
      // A meridian with two panel seams bowing away from it on each side —
      // the six-panel wrap as it reads from one side of the ball.
      canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 0.64, height: r * 2), panel);
      for (final dir in [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
              center: c + Offset(-dir * r * 0.42, 0),
              width: r * 2.3,
              height: r * 2.3),
          panel,
        );
      }
    });
  }

  void _cricketBat(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Handle, then grip, then blade — the blade covers the handle's foot, so
    // the splice does not need drawing.
    final handle = Rect.fromLTRB(w * 0.40, 0, w * 0.60, h * 0.40);
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, Radius.circular(w * 0.1)),
      Paint()..color = AppColors.propGrip,
    );
    final rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.006
      ..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 1; i < 9; i++) {
      final y = handle.top + handle.height * i / 9;
      canvas.drawLine(Offset(handle.left, y), Offset(handle.right, y), rib);
    }

    final blade = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.16, h * 0.33, w * 0.84, h),
      topLeft: Radius.circular(w * 0.16),
      topRight: Radius.circular(w * 0.16),
      bottomLeft: Radius.circular(w * 0.10),
      bottomRight: Radius.circular(w * 0.10),
    );
    canvas.drawRRect(
      blade,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w * 0.16, 0),
          Offset(w * 0.84, 0),
          [
            Color.lerp(AppColors.propWillow, Colors.white, 0.35)!,
            AppColors.propWillow,
            AppColors.propWillowEdge,
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    // The grain, and the edge that gives the blade its thickness.
    canvas.save();
    canvas.clipRRect(blade);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..color = AppColors.propWillowEdge.withValues(alpha: 0.5);
    for (var i = 1; i < 6; i++) {
      final x = w * 0.16 + w * 0.68 * i / 6;
      canvas.drawLine(Offset(x, h * 0.36), Offset(x, h), grain);
    }
    canvas.drawRect(
      Rect.fromLTRB(w * 0.76, h * 0.33, w * 0.84, h),
      Paint()..color = AppColors.propWillowEdge.withValues(alpha: 0.65),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PropPainter oldDelegate) => oldDelegate.prop != prop;
}
