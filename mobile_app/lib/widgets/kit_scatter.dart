import 'package:flutter/material.dart';

import 'sport_props.dart';

/// Which arrangement of the kit a screen wants.
enum KitLayout {
  /// The login page: corners filled top and bottom, around a tall stack of
  /// cards that reaches neither.
  login,

  /// The OTP page: the card runs nearly the full height, so only the floor
  /// under it is left — a ball at one foot and a bat at the other.
  otp,
}

/// The sports kit tucked into a page's corners.
///
/// Every piece sits behind the content and half of each one runs off an edge,
/// so the page reads as a corner of a kit bag rather than a row of stickers.
/// The football is the photograph from the design; the rest are painted to
/// match it — see [SportPropIcon].
///
/// **Parent this above the `Scaffold`, not inside its body.** The body is
/// shrunk by `resizeToAvoidBottomInset` when the keyboard opens and a `Stack`
/// clips to its own bounds, so a scatter inside it gets sliced along the
/// keyboard's edge, mid-ball, with dead page below. Out above the `Scaffold`
/// nothing resizes it, and the keyboard simply covers the bottom of the page.
class KitScatter extends StatelessWidget {
  const KitScatter({super.key, required this.size, required this.layout});

  /// The whole page, not the box left over after an inset.
  final Size size;

  final KitLayout layout;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          children: switch (layout) {
            KitLayout.login => _login(size),
            KitLayout.otp => _otp(size),
          },
        ),
      ),
    );
  }

  static List<Widget> _login(Size size) {
    final w = size.width;
    final h = size.height;

    return [
      // Top right, above the welcome: the biggest piece, mostly off-page.
      Positioned(
        top: -w * 0.10,
        right: -w * 0.16,
        child: SportPropIcon(SportProp.basketball, size: w * 0.46),
      ),
      // Beside the deck, where the headline has already narrowed.
      Positioned(
        top: h * 0.20,
        right: -w * 0.04,
        child: SportPropIcon(SportProp.cricketBall, size: w * 0.17),
      ),
      Positioned(
        top: h * 0.30,
        right: w * 0.16,
        child: SportPropIcon(SportProp.tennisBall, size: w * 0.10),
      ),
      // The bottom, under the form card.
      Positioned(left: -w * 0.05, bottom: 0, child: _Football(width: w * 0.30)),
      Positioned(
        right: w * 0.06,
        bottom: -h * 0.06,
        child: SportPropIcon(SportProp.cricketBat, size: w * 0.17, turns: 0.06),
      ),
      Positioned(
        right: -w * 0.06,
        bottom: h * 0.06,
        child: SportPropIcon(SportProp.volleyball, size: w * 0.24),
      ),
    ];
  }

  static List<Widget> _otp(Size size) {
    final w = size.width;

    return [
      // Both feet of the page, and nothing above them: the verify card is the
      // screen here and anything higher would sit behind text rather than
      // beside it.
      Positioned(
        left: -w * 0.06,
        bottom: -w * 0.05,
        child: _Football(width: w * 0.28),
      ),
      Positioned(
        right: -w * 0.02,
        bottom: -w * 0.16,
        child: SportPropIcon(SportProp.cricketBat, size: w * 0.19, turns: 0.05),
      ),
      Positioned(
        right: -w * 0.06,
        bottom: -w * 0.08,
        child: SportPropIcon(SportProp.cricketBall, size: w * 0.18),
      ),
    ];
  }
}

/// The one piece of the kit that is a photograph.
class _Football extends StatelessWidget {
  const _Football({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/login_ball.png',
      width: width,
      // The scatter is decoration: a missing asset must cost the page nothing.
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
