// The onboarding pages stack a hero, a headline, a deck and three two-line
// feature rows into one column, and the chrome under them is a fixed-height
// button plus two text buttons — the shape that overflows first at a large
// text scale. Renders all three pages across both target devices, both text
// scales and both brightnesses (the flow follows the device theme), and fails
// on any overflow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/screens/onboarding_screen.dart';

const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};

const _scales = <double>[1.0, 1.3];

void main() {
  for (final device in _devices.entries) {
    for (final scale in _scales) {
      for (final brightness in Brightness.values) {
        testWidgets(
            'onboarding lays out on ${device.key} at ${scale}x '
            '(${brightness.name})', (tester) async {
          tester.view
            ..physicalSize = device.value
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const OnboardingScreen(),
            ),
          ));
          await tester.pumpAndSettle();

          expect(find.text('Book Slots\nInstantly'), findsOneWidget);
          expect(find.text('Next'), findsOneWidget);
          expect(tester.takeException(), isNull);

          for (final headline in [
            'Discover\nNearby Venues',
            'Join Games &\nMeet Players',
          ]) {
            await tester.fling(
                find.byType(PageView), const Offset(-400, 0), 1000);
            await tester.pumpAndSettle();
            expect(find.text(headline), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          // The last page's button commits instead of advancing.
          expect(find.text('Get Started'), findsOneWidget);
        });
      }
    }
  }
}
