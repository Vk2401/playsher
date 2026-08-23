// The login screen stacks a bled photograph, a welcome, a trust card and a
// form card in one scroll view, and it is the first screen in the app with a
// text field — so the keyboard case is part of "done". Renders it across both
// target devices, both text scales and both brightnesses, with the keyboard
// both down and up, and fails on any overflow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/screens/phone_screen.dart';
import 'package:playsher_app/widgets/sport_props.dart';
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
                  // copyWith, not a bare MediaQueryData: a fresh one has no
                  // `size`, which silently lays the corner kit out at zero and
                  // makes every geometry assertion below vacuous.
                  home: Builder(
                    builder: (context) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                        viewInsets: EdgeInsets.only(bottom: keyboard),
                      ),
                      child: const PhoneScreen(),
                    ),
                  ),
                ),
              );

          await tester.pumpWidget(wrap(keyboard: 0));
          await tester.pump();

          expect(find.text('Mobile Number'), findsOneWidget);
          expect(find.text('Send OTP'), findsOneWidget);
          expect(tester.takeException(), isNull);

          final kitDown = tester.widgetList(find.byType(SportPropIcon)).length;
          expect(kitDown, greaterThan(0));

          // The kit must sit outside the Scaffold. Inside it, the body is
          // shrunk by `resizeToAvoidBottomInset` and the Stack clips to that
          // smaller box — which sliced the football in half along the
          // keyboard's edge and left dead page below it.
          expect(
            find.descendant(
              of: find.byType(Scaffold),
              matching: find.byType(SportPropIcon),
            ),
            findsNothing,
            reason: 'the kit must not be parented to the resizable body',
          );

          final kitRects = tester
              .widgetList(find.byType(SportPropIcon))
              .map((w) => tester.getRect(find.byWidget(w)))
              .toList();

          // With the keyboard up the field must still be reachable, the kit
          // must still be there, and every piece must be exactly where it was
          // — it used to be dropped outright the moment the field was focused.
          await tester.pumpWidget(wrap(keyboard: 336));
          await tester.pump();

          expect(find.byType(TextFormField), findsOneWidget);
          expect(find.byType(SportPropIcon), findsNWidgets(kitDown));
          expect(
            tester
                .widgetList(find.byType(SportPropIcon))
                .map((w) => tester.getRect(find.byWidget(w)))
                .toList(),
            kitRects,
            reason: 'the keyboard must not move the kit',
          );
          expect(tester.takeException(), isNull);

          await tester.ensureVisible(find.byType(TextFormField));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
