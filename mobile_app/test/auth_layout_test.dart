// The two screens between a verified number and an account: the OTP card and
// the profile form. Both are text-field screens, so the keyboard case is part
// of "done" — they are rendered across both target devices, both text scales
// and both brightnesses, with the keyboard down and up, and fail on any
// overflow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/screens/otp_screen.dart';
import 'package:playsher_app/screens/register_screen.dart';
import 'package:playsher_app/widgets/security_shield.dart';
import 'package:playsher_app/widgets/sport_props.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
  // The narrowest phone the app is expected on: six OTP boxes have to fit
  // across it, and they are the widest fixed row in the flow.
  'small': Size(360, 780),
};

const _scales = <double>[1.0, 1.3];

/// copyWith, not a bare MediaQueryData: a fresh one has no `size`, which lays
/// the corner kit out at zero and makes any geometry assertion vacuous.
Widget _wrap(Widget screen, Brightness brightness, double scale,
        double keyboard) =>
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: screen,
          ),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final device in _devices.entries) {
    for (final scale in _scales) {
      for (final brightness in Brightness.values) {
        final where = '${device.key} at ${scale}x (${brightness.name})';

        testWidgets('OTP lays out on $where', (tester) async {
          tester.view
            ..physicalSize = device.value
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          Widget screen(double keyboard) => _wrap(
              const OtpScreen(mobile: '+918610123456'),
              brightness,
              scale,
              keyboard);

          await tester.pumpWidget(screen(0));
          await tester.pump();

          expect(find.text('Verify OTP'), findsOneWidget);
          expect(find.text('Verify & Continue'), findsOneWidget);
          expect(find.byType(SecurityShield), findsOneWidget);
          expect(tester.takeException(), isNull);

          // The kit must sit outside the Scaffold: inside it, the body is
          // shrunk by `resizeToAvoidBottomInset` and the Stack clips to that
          // smaller box, slicing the props along the keyboard's edge. This
          // screen always has the keyboard up, so it is the one that matters.
          expect(
            find.descendant(
              of: find.byType(Scaffold),
              matching: find.byType(SportPropIcon),
            ),
            findsNothing,
            reason: 'the kit must not be parented to the resizable body',
          );

          final kit = tester
              .widgetList(find.byType(SportPropIcon))
              .map((w) => tester.getRect(find.byWidget(w)))
              .toList();
          expect(kit, isNotEmpty);

          await tester.pumpWidget(screen(336));
          await tester.pump();

          expect(
            tester
                .widgetList(find.byType(SportPropIcon))
                .map((w) => tester.getRect(find.byWidget(w)))
                .toList(),
            kit,
            reason: 'the keyboard must not move the kit',
          );
          expect(tester.takeException(), isNull);

          // The CTA stays disabled until six digits are in — the same flag
          // that stops a second verify while the first is in flight.
          final cta = tester.widget<ElevatedButton>(find.ancestor(
            of: find.text('Verify & Continue'),
            matching: find.byType(ElevatedButton),
          ));
          expect(cta.onPressed, isNull);

          // Unmount so the countdown's periodic timer is cancelled.
          await tester.pumpWidget(const SizedBox.shrink());
        });

        testWidgets('profile lays out on $where', (tester) async {
          tester.view
            ..physicalSize = device.value
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          Widget screen(double keyboard) => _wrap(
              const RegisterScreen(mobile: '+919876543210'),
              brightness,
              scale,
              keyboard);

          await tester.pumpWidget(screen(0));
          await tester.pump();

          expect(find.text('Mobile Number'), findsOneWidget);
          expect(find.text('Verified'), findsOneWidget);
          expect(find.text('Get Started'), findsOneWidget);
          // The verified number is shown back spaced, not as it is stored.
          expect(find.text('+91 98765 43210'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(screen(336));
          await tester.pump();

          expect(find.byType(TextFormField), findsNWidgets(2));
          expect(tester.takeException(), isNull);

          // Both fields must still be reachable with the keyboard up.
          for (final field in [
            find.byType(TextFormField).first,
            find.byType(TextFormField).last,
          ]) {
            await tester.ensureVisible(field);
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }

  testWidgets('the profile form refuses an empty name', (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
        const RegisterScreen(mobile: '+919876543210'),
        Brightness.light,
        1.0,
        0));
    await tester.pump();

    await tester.ensureVisible(find.text('Get Started'));
    await tester.pump();
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
  });
}
