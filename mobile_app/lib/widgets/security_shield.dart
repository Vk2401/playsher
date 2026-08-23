import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// The shield the OTP screen is verified behind: a lit crest, a padlock, and
/// the bubble the code arrives in.
///
/// Painted rather than shipped as a PNG, for the reason the sports props are
/// (see `sport_props.dart`): it is a few gradients and two arcs, it resizes to
/// whatever corner it is tucked into without a crop, and it has no background
/// of its own — it composites onto the card exactly as a transparent asset
/// would, in either theme.
class SecurityShield extends StatelessWidget {
  const SecurityShield({super.key, required this.size});

  /// Width in logical pixels; the crest is a little taller than it is wide.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(size, size * 1.06),
          painter: const _ShieldPainter(),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The crest sits in the left three-quarters; the right quarter is left for
    // the bubble to overlap into, as the design has it.
    final w = size.width * 0.78;
    final h = size.height * 0.86;
    final origin = Offset(size.width * 0.06, size.height * 0.06);

    _halo(canvas, size, Rect.fromLTWH(origin.dx, origin.dy, w, h));
    _crest(canvas, Rect.fromLTWH(origin.dx, origin.dy, w, h));
    _padlock(canvas, Rect.fromLTWH(origin.dx, origin.dy, w, h));
    _bubble(canvas, size);
  }

  /// The ring of light behind the crest — one thin arc, cropped by the widget's
  /// own box, which is what makes it read as depth rather than a drawn circle.
  void _halo(Canvas canvas, Size size, Rect crest) {
    canvas.drawCircle(
      crest.center.translate(crest.width * 0.10, -crest.height * 0.06),
      crest.width * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = crest.width * 0.045
        ..color = AppColors.shieldMid.withValues(alpha: 0.16),
    );
  }

  /// The shield outline: square shoulders, sides that fall away, and a point.
  Path _shieldPath(Rect r) {
    final path = Path()..moveTo(r.left + r.width * 0.5, r.top);

    // Up over the right shoulder and down the flank.
    path.lineTo(r.right - r.width * 0.06, r.top + r.height * 0.14);
    path.lineTo(r.right - r.width * 0.06, r.top + r.height * 0.52);
    // The flank curves in towards the point rather than meeting it straight.
    path.cubicTo(
      r.right - r.width * 0.08, r.top + r.height * 0.78,
      r.left + r.width * 0.72, r.top + r.height * 0.94,
      r.left + r.width * 0.5, r.bottom,
    );
    // And back up the left, mirrored.
    path.cubicTo(
      r.left + r.width * 0.28, r.top + r.height * 0.94,
      r.left + r.width * 0.08, r.top + r.height * 0.78,
      r.left + r.width * 0.06, r.top + r.height * 0.52,
    );
    path.lineTo(r.left + r.width * 0.06, r.top + r.height * 0.14);
    path.close();
    return path;
  }

  void _crest(Canvas canvas, Rect r) {
    final path = _shieldPath(r);

    // The shadow the crest casts on the card, which is what lifts it off the
    // surface — without it the whole thing reads as a flat sticker.
    canvas.drawPath(
      path.shift(Offset(0, r.height * 0.045)),
      Paint()
        ..color = AppColors.shieldDeep.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.width * 0.07),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topLeft,
          r.bottomRight,
          [AppColors.shieldLight, AppColors.shieldMid, AppColors.shieldDeep],
          [0.0, 0.46, 1.0],
        ),
    );

    // The bevel: the left half catches the light, the right falls into shade.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topLeft,
          Offset(r.right, r.top),
          [
            AppColors.shieldMetal.withValues(alpha: 0.26),
            AppColors.shieldMetal.withValues(alpha: 0.0),
            AppColors.shieldDeep.withValues(alpha: 0.30),
          ],
          [0.0, 0.42, 1.0],
        ),
    );
    canvas.restore();
  }

  /// The padlock: a shackle over a rounded body, with the keyhole cut out of
  /// it so the crest shows through rather than being painted over.
  void _padlock(Canvas canvas, Rect r) {
    final body = Rect.fromCenter(
      center: r.center.translate(0, r.height * 0.04),
      width: r.width * 0.40,
      height: r.height * 0.30,
    );
    final metal = Paint()..color = AppColors.shieldMetal;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(body.center.dx, body.top),
        width: body.width * 0.62,
        height: body.width * 0.72,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = body.width * 0.15
        ..color = AppColors.shieldMetal,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(body.height * 0.28)),
      metal,
    );

    // Keyhole — a circle over a short taper, punched out of the body.
    final keyhole = Path()
      ..addOval(Rect.fromCircle(
        center: body.center.translate(0, -body.height * 0.08),
        radius: body.height * 0.15,
      ))
      ..addRect(Rect.fromCenter(
        center: body.center.translate(0, body.height * 0.16),
        width: body.height * 0.14,
        height: body.height * 0.30,
      ));
    canvas.drawPath(keyhole, Paint()..color = AppColors.shieldMid);
  }

  /// The message the code arrives in, tucked into the crest's lower right.
  void _bubble(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      size.width * 0.56,
      size.height * 0.56,
      size.width * 0.42,
      size.height * 0.24,
    );
    final radius = Radius.circular(r.height * 0.34);

    canvas.drawRRect(
      RRect.fromRectAndRadius(r, radius),
      Paint()
        ..color = AppColors.shieldDeep.withValues(alpha: 0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r.height * 0.16),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, radius),
      Paint()..color = AppColors.shieldBubble,
    );

    // The tail, pointing back at the crest.
    canvas.drawPath(
      Path()
        ..moveTo(r.left + r.width * 0.14, r.bottom - r.height * 0.10)
        ..lineTo(r.left + r.width * 0.02, r.bottom + r.height * 0.22)
        ..lineTo(r.left + r.width * 0.34, r.bottom - r.height * 0.02)
        ..close(),
      Paint()..color = AppColors.shieldBubble,
    );

    // Three asterisks: the code, still hidden.
    final star = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r.height * 0.075
      ..strokeCap = StrokeCap.round
      ..color = AppColors.shieldMid;
    final arm = r.height * 0.13;
    for (var i = 0; i < 3; i++) {
      final c = Offset(
        r.left + r.width * (0.27 + i * 0.23),
        r.center.dy,
      );
      for (var k = 0; k < 3; k++) {
        final a = math.pi / 3 * k - math.pi / 2;
        canvas.drawLine(
          c + Offset(math.cos(a), math.sin(a)) * arm,
          c - Offset(math.cos(a), math.sin(a)) * arm,
          star,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ShieldPainter oldDelegate) => false;
}
