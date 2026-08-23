// The splash frame is painted, not laid out from a bitmap, so a mistake in
// `SplashStage`'s geometry is a paint-time exception that `flutter analyze`
// cannot see. Renders it, and the loader over it, at both target devices and
// both brightnesses, and fails on anything thrown while painting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/widgets/splash_stage.dart';

const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};

void main() {
  for (final device in _devices.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('the splash stadium and loader paint on ${device.key} '
          '(${brightness.name})', (tester) async {
        tester.view
          ..physicalSize = device.value
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                SplashStage(),
                Center(child: SplashProgress(width: 150)),
              ],
            ),
          ),
        ));

        // A few frames of the loader's lap, so the bar is painted at more than
        // one point on its track.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));

        expect(tester.takeException(), isNull);
      });
    }
  }
}
