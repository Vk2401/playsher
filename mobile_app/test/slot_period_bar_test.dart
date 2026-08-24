// The period tabs above the slot row.
//
// Greyed-out is not a state anyone can read on its own — least of all in
// greyscale, and least of all when the question is "is it worth tapping
// this?". Every tab says how many slots it still holds, in words.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/widgets/booking_picker.dart';

Widget _bar({
  required SlotPeriod selected,
  required Map<SlotPeriod, int> counts,
  void Function(SlotPeriod)? onSelected,
}) =>
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SlotPeriodBar(
          selected: selected,
          onSelected: onSelected ?? (_) {},
          countFor: (p) => counts[p] ?? 0,
        ),
      ),
    );

void main() {
  testWidgets('each tab says how many slots it still holds', (tester) async {
    await tester.pumpWidget(_bar(
      selected: SlotPeriod.evening,
      counts: const {SlotPeriod.evening: 6, SlotPeriod.night: 1},
    ));

    expect(find.text('No slots'), findsNWidgets(2)); // morning, afternoon
    expect(find.text('6 left'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);
  });

  testWidgets('a tap reports the period that was pressed', (tester) async {
    final taps = <SlotPeriod>[];
    await tester.pumpWidget(_bar(
      selected: SlotPeriod.evening,
      counts: const {SlotPeriod.evening: 6, SlotPeriod.night: 2},
      onSelected: taps.add,
    ));

    await tester.tap(find.text('Night'));
    expect(taps, [SlotPeriod.night]);
  });
}
