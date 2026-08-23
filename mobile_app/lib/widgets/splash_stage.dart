import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// The stadium the splash screen stands on.
///
/// Painted rather than shipped as a bitmap: the artwork is flat gradients, an
/// ellipse and a handful of arcs, so a painter costs a few hundred bytes where
/// a photo that stays sharp on a 3x phone costs a megabyte — and it scales to
/// every aspect ratio without a crop that puts the halfway line off centre.
///
/// It follows the device theme through [FramePalette]: the same ground by day
/// and under floodlights, so a fresh install on a dark phone does not open on
/// a white screen. The native launch screen carries the matching pair — see
/// `launch_background.xml` and `values-night/colors.xml`.
class SplashStage extends StatelessWidget {
  const SplashStage({super.key});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _StadiumPainter(context.frame),
          size: Size.infinite,
          isComplex: true,
        ),
      );
}

class _StadiumPainter extends CustomPainter {
  const _StadiumPainter(this.palette);

  final FramePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // The bands the frame is built from, as fractions of the height, so the
    // horizon sits just below the lockup on a tall phone and on a short one.
    final standsTop = h * 0.545;
    final horizon = h * 0.628;

    // The turf runs to the bottom edge: the near touchline is off-screen, the
    // way it is when you are standing on the pitch. Stopping it short left a
    // band of empty page under the stadium.
    final pitchEnd = h;

    _sky(canvas, w, horizon);
    _rays(canvas, w, h, horizon);
    _stands(canvas, w, standsTop, horizon);
    _floodlights(canvas, w, standsTop, horizon);
    _pitch(canvas, w, horizon, pitchEnd);
    _markings(canvas, w, horizon, pitchEnd);
  }

  void _sky(Canvas canvas, double w, double horizon) {
    final rect = Rect.fromLTRB(0, 0, w, horizon);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.page,
            palette.skyMid,
            palette.skyHaze,
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(rect),
    );
  }

  /// The soft light sweeping in from the corners: wide, low-opacity wedges from
  /// a vanishing point below the pitch, clipped to the sky.
  void _rays(Canvas canvas, double w, double h, double horizon) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w, horizon));

    final origin = Offset(w / 2, h * 0.74);
    final reach = h * 1.15;
    final paint = Paint()..color = palette.ray;
    const spread = 0.07;

    for (final angle in const [-1.34, -1.05, -0.76, 0.76, 1.05, 1.34]) {
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(origin.dx + reach * math.sin(angle - spread),
              origin.dy - reach * math.cos(angle - spread))
          ..lineTo(origin.dx + reach * math.sin(angle + spread),
              origin.dy - reach * math.cos(angle + spread))
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  /// The far stand: a blue band that curves up towards the edges, with a
  /// skyline behind it.
  void _stands(Canvas canvas, double w, double standsTop, double horizon) {
    final depth = horizon - standsTop;
    final band = Path()
      ..moveTo(0, standsTop - depth * 0.55)
      ..quadraticBezierTo(
          w / 2, standsTop + depth * 0.34, w, standsTop - depth * 0.55)
      ..lineTo(w, horizon)
      ..lineTo(0, horizon)
      ..close();

    final rect = Rect.fromLTRB(0, standsTop - depth, w, horizon);
    canvas.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.standLight, palette.standDeep],
        ).createShader(rect),
    );

    // Skyline: a blurred run of blocks, only just darker than the stand, so it
    // reads as depth behind it rather than as a bar chart drawn on top of it.
    canvas.save();
    canvas.clipPath(band);
    final block = Paint()
      ..color = palette.skyline
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth * 0.06);
    const heights = <double>[
      0.34, 0.62, 0.45, 0.78, 0.40, 0.55, 0.88, 0.48, 0.36, 0.70, //
      0.42, 0.60, 0.95, 0.52, 0.38, 0.66, 0.44, 0.80, 0.35, 0.58, //
      0.47, 0.72, 0.39, 0.54, 0.68, 0.41,
    ];
    final unit = w / heights.length;
    final tallest = depth * 0.72;
    for (var i = 0; i < heights.length; i++) {
      final tall = tallest * heights[i];
      // Widths vary with the height so no two neighbours share an edge.
      final wide = unit * (0.55 + heights[i] * 0.5);
      canvas.drawRect(
        Rect.fromLTWH(i * unit, standsTop - tall * 0.16, wide, tall),
        block,
      );
    }
    canvas.restore();
  }

  /// The two floodlight banks: a grid of lamps under a wide glow.
  void _floodlights(Canvas canvas, double w, double standsTop, double horizon) {
    final depth = horizon - standsTop;
    final y = standsTop + depth * 0.10;
    final bankW = w * 0.15;
    final bankH = depth * 0.52;

    for (final cx in [w * 0.115, w * 0.885]) {
      final centre = Offset(cx, y + bankH / 2);

      canvas.drawCircle(
        centre,
        bankW * 1.5,
        Paint()
          ..shader = RadialGradient(
            colors: [palette.glow, palette.glow.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: centre, radius: bankW * 1.5)),
      );

      const cols = 4;
      const rows = 3;
      final lampW = bankW / (cols * 1.5);
      final lampH = bankH / (rows * 1.6);
      final lamp = Paint()..color = palette.lamp;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                cx - bankW / 2 + c * lampW * 1.5,
                y + r * lampH * 1.6,
                lampW,
                lampH,
              ),
              Radius.circular(lampW * 0.3),
            ),
            lamp,
          );
        }
      }
    }
  }

  /// The turf, in perspective: bright at the halfway line, deepening towards
  /// the camera, then given away to the page again at [pitchEnd].
  void _pitch(Canvas canvas, double w, double horizon, double pitchEnd) {
    final rect = Rect.fromLTRB(0, horizon, w, pitchEnd);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.turfFar,
            palette.turfMid,
            palette.turfNear,
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(rect),
    );

    // Mown stripes. Trapezoids that widen towards the camera, so the eye reads
    // a pitch running away rather than a flat green rectangle.
    canvas.save();
    canvas.clipRect(rect);
    final stripe = Paint()..color = palette.turfStripe;
    const bands = 7;
    final farUnit = w / bands;
    final nearUnit = w * 1.7 / bands;
    final nearLeft = -(w * 1.7 - w) / 2;
    for (var i = 0; i < bands; i += 2) {
      canvas.drawPath(
        Path()
          ..moveTo(i * farUnit, horizon)
          ..lineTo((i + 1) * farUnit, horizon)
          ..lineTo(nearLeft + (i + 1) * nearUnit, pitchEnd)
          ..lineTo(nearLeft + i * nearUnit, pitchEnd)
          ..close(),
        stripe,
      );
    }
    canvas.restore();
  }

  /// Centre circle and halfway line, flattened into the same perspective.
  void _markings(Canvas canvas, double w, double horizon, double pitchEnd) {
    final depth = pitchEnd - horizon;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = palette.line;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, horizon, w, pitchEnd));

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, horizon + depth * 0.30),
        width: w * 0.62,
        height: depth * 0.40,
      ),
      line,
    );

    // The halfway line, narrowing as it recedes — two edges, not one stroke,
    // so it tapers the way the stripes do.
    canvas.drawPath(
      Path()
        ..moveTo(w / 2 - 0.8, horizon)
        ..lineTo(w / 2 + 0.8, horizon)
        ..lineTo(w / 2 + 3.4, pitchEnd)
        ..lineTo(w / 2 - 3.4, pitchEnd)
        ..close(),
      Paint()..color = palette.line,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StadiumPainter oldDelegate) =>
      oldDelegate.palette != palette;
}

/// The splash's wait indicator: a slim determinate-looking bar sweeping the
/// brand blue across a translucent track.
///
/// It is a *loop* — progress feedback, which the motion rules exempt from any
/// future reduce-motion suppression, because a frozen loader reads as a hung
/// app.
class SplashProgress extends StatefulWidget {
  const SplashProgress({super.key, this.width = 150});

  /// Length of the track in logical pixels.
  final double width;

  @override
  State<SplashProgress> createState() => _SplashProgressState();
}

class _SplashProgressState extends State<SplashProgress>
    with SingleTickerProviderStateMixin {
  static const _height = 4.0;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The lit segment is a third of the track, so there is always both a
    // filled part to watch and an empty part for it to move into.
    const segment = 0.34;

    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: widget.width,
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.frame.track,
            borderRadius: BorderRadius.circular(_height),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_height),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Align(
                // -1 → 1 and back, so the segment runs out one end and returns
                // rather than teleporting to the start every lap.
                alignment: Alignment(
                  -1 + 2 * Curves.easeInOut.transform(
                    (_ctrl.value * 2 <= 1 ? _ctrl.value * 2 : 2 - _ctrl.value * 2),
                  ),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: segment,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(_height),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
