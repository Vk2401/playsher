// The login screen stacks a bled photograph, a welcome, a trust card and a
// form card in one scroll view, and it is the first screen in the app with a
// text field — so the keyboard case is part of "done". Renders it across both
// target devices, both text scales and both brightnesses, with the keyboard
// both down and up, and fails on any overflow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/screens/phone_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};

const _scales = <double>[1.0, 1.3];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final device in _devices.entries) {
    for (final scale in _scales) {
      for (final brightness in Brightness.values) {
        testWidgets(
            'login lays out on ${device.key} at ${scale}x '
            '(${brightness.name})', (tester) async {
          tester.view
            ..physicalSize = device.value
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          Widget wrap({required double keyboard}) => ProviderScope(
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: MediaQuery(
                    data: MediaQueryData(
                      textScaler: TextScaler.linear(scale),
                      viewInsets: EdgeInsets.only(bottom: keyboard),
                    ),
                    child: const PhoneScreen(),
                  ),
                ),
              );

          await tester.pumpWidget(wrap(keyboard: 0));
          await tester.pump();

          expect(find.text('Mobile Number'), findsOneWidget);
          expect(find.text('Send OTP'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // With the keyboard up the field must still be reachable and the
          // corner decoration must stand down.
          await tester.pumpWidget(wrap(keyboard: 336));
          await tester.pump();

          expect(find.byType(TextFormField), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.byType(TextFormField));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
