// The redesigned checkout screen: card + payment method + price details +
// sticky bar, all built from real widgets rather than a mock. Guards the
// three things a from-scratch redesign most easily gets wrong — an overflow
// in a tight row, a null field crashing the build, and the pay-at-ground
// breakdown vanishing once the online-only fields were added.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/ground_sport_model.dart';
import 'package:playsher_app/models/sport_model.dart';
import 'package:playsher_app/screens/booking_flow_screen.dart';

Widget _host(Map<String, dynamic> extra, {Brightness brightness = Brightness.dark}) {
  return ProviderScope(
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: BookingFlowScreen(groundId: 1, extra: extra),
    ),
  );
}

Map<String, dynamic> _extra({bool longName = false}) => {
      'groundSport': const GroundSportModel(
        id: 10,
        groundId: 1,
        sport: SportModel(id: 1, name: 'Football'),
        pricePerSlot: 200,
        maxSlots: 4,
      ),
      'date': '2026-08-24',
      'slotIds': [101],
      'totalPrice': 200,
      'pricePerSlot': 200.0,
      'groundName': longName
          ? 'Elite Football Arena & Multi-Sport Recreation Complex'
          : 'Elite Football Arena',
      'groundLocality': 'DHA Phase 5 · Lahore',
    };

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'renders without overflow — ${brightness.name}, ${scale}x text',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(_host(_extra(), brightness: brightness));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Confirm Booking'), findsOneWidget);
        expect(find.text('Payment Method'), findsOneWidget);
        expect(find.text('Price Details'), findsOneWidget);
      });
    }
  }

  testWidgets('a long ground name does not overflow the summary card',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_extra(longName: true)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('pay-at-ground shows the advance and the balance due',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_extra()));
    await tester.pumpAndSettle();

    // Pay at Ground is selected on arrival.
    expect(find.textContaining('Due at the ground'), findsOneWidget);
    expect(find.textContaining('Pay Now (10% advance)'), findsOneWidget);

    await tester.tap(find.text('Pay Online'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Due at the ground'), findsNothing);
    expect(find.textContaining('Pay Now (100% online)'), findsOneWidget);
    expect(find.text('Secure Payment'), findsOneWidget);
    expect(find.text('Instant Confirmation'), findsOneWidget);
  });
}
