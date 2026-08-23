// The two screens between a verified number and an account: the OTP card and
// the profile form. Both are text-field screens, so the keyboard case is part
// of "done" — they are rendered across both target devices, both text scales
// and both brightnesses, with the keyboard down and up, and fail on any
// overflow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/screens/location_screen.dart';
import 'package:playsher_app/screens/otp_screen.dart';
import 'package:playsher_app/screens/register_screen.dart';
import 'package:playsher_app/widgets/location_hero.dart';
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

        testWidgets('location lays out on $where', (tester) async {
          tester.view
            ..physicalSize = device.value
            ..devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_wrap(
              const LocationScreen(fromRegister: true), brightness, scale, 0));
          await tester.pump();

          expect(find.byType(LocationHero), findsOneWidget);
          expect(find.text('Allow Location Access'), findsOneWidget);
          expect(find.text('Skip for now'), findsOneWidget);
          expect(find.text('Find grounds near you'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // The two answers sit on the bottom edge, not at the end of the
          // scroll: inside it, a page shorter than the screen left them
          // floating with the slack underneath.
          for (final action in ['Allow Location Access', 'Skip for now']) {
            expect(
              find.descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.text(action),
              ),
              findsNothing,
              reason: '"$action" must not scroll with the reasons',
            );
          }

          // Reached later from the app rather than straight after sign-up, it
          // is a request rather than a greeting.
          await tester.pumpWidget(
              _wrap(const LocationScreen(), brightness, scale, 0));
          await tester.pump();

          expect(find.text('Enable Location'), findsOneWidget);
          expect(tester.takeException(), isNull);
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

  // The design is one screenful, and it must stay one.
  //
  // This cannot assert "does not scroll" directly: the test font draws every
  // glyph as a square of the font size, so every string is far wider than any
  // real face renders it and the page wraps into much more height than a
  // device ever gives it. Measured with a real face at the default text scale
  // and a phone's own insets, both devices below come out at 0 — nothing
  // below the fold. What is guarded here is the budget: add a field or a
  // section and this number climbs, which is the regression worth catching.
  // The scroll view itself stays for the cases that genuinely need it — a
  // small phone, or a large text scale.
  for (final device in const {
    'Pixel 7': (Size(412, 915), 130.0),
    'iPhone 14': (Size(390, 844), 240.0),
  }.entries) {
    testWidgets('the profile page stays within one screen on ${device.key}',
        (tester) async {
      final (size, budget) = device.value;
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0
        // A phone's status bar and gesture area are part of the height the
        // page has to fit into; without them this measures a screen nobody
        // has.
        ..padding = const FakeViewPadding(top: 48, bottom: 34);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(const RegisterScreen(mobile: '+919876543210'),
          Brightness.light, 1.0, 0));
      await tester.pump();

      // .first, and scoped to the page's own scroll view: every TextField
      // carries a Scrollable of its own.
      final extent = tester
          .state<ScrollableState>(find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first)
          .position
          .maxScrollExtent;

      expect(extent, lessThanOrEqualTo(budget),
          reason: 'the profile page has grown past one screen');
    });
  }

  // Same budget guard as the profile page, and the same caveat: measured with
  // a real face at the default text scale and a phone's own insets, this page
  // comes out at 0 on both devices.
  for (final device in const {
    'Pixel 7': (Size(412, 915), 225.0),
    'iPhone 14': (Size(390, 844), 310.0),
  }.entries) {
    testWidgets('the location page stays within one screen on ${device.key}',
        (tester) async {
      final (size, budget) = device.value;
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0
        ..padding = const FakeViewPadding(top: 48, bottom: 34);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          _wrap(const LocationScreen(fromRegister: true), Brightness.light, 1.0, 0));
      await tester.pump();

      final extent = tester
          .state<ScrollableState>(find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first)
          .position
          .maxScrollExtent;

      expect(extent, lessThanOrEqualTo(budget),
          reason: 'the location page has grown past one screen');
    });
  }

  // Whatever the phone's height, the answers are on its bottom edge — the
  // reported bug was a band of empty page below them on a tall screen.
  for (final height in [844.0, 915.0, 950.0]) {
    testWidgets('the location answers sit at the bottom of a ${height}px phone',
        (tester) async {
      const bottomInset = 34.0;
      tester.view
        ..physicalSize = Size(412, height)
        ..devicePixelRatio = 1.0
        ..padding = const FakeViewPadding(top: 48, bottom: bottomInset);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          _wrap(const LocationScreen(), Brightness.light, 1.0, 0));
      await tester.pump();

      final skip = tester.getRect(find.text('Skip for now'));
      final floor = height - bottomInset;

      // Within a button's own padding of the safe area's bottom edge, and
      // never past it.
      expect(skip.bottom, lessThanOrEqualTo(floor));
      expect(floor - skip.bottom, lessThan(40),
          reason: 'the answers have drifted up the page');
    });
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

  testWidgets('leaving the profile form asks before logging out',
      (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const RegisterScreen(mobile: '+919876543210'),
        Brightness.light, 1.0, 0));
    await tester.pump();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);

    // Staying dismisses the dialog and leaves the form as it was.
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing);
    expect(find.text('Mobile Number'), findsOneWidget);
  });
}
