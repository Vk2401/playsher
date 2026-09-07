// The bar carries the one committing action on a screen, so a button that does
// not render is a screen that cannot be used.
//
// `Expanded(flex: 0)` plus `width: double.infinity` made RenderFlex lay the
// button out against an unbounded main axis and then force an infinite width:
// an assertion in debug, and a collapsed, invisible button in release. It hit
// every bar without a price — Save changes, Publish game, Book Coach, Request
// session — and none of them were covered, because the existing render checks
// all passed a price.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/widgets/sticky_bottom_bar.dart';

const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};
const _scales = <double>[1.0, 1.3];

Widget _host(
  Widget bar, {
  required Brightness brightness,
  required double scale,
}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: bar,
        ),
      ),
    );

void main() {
  Future<void> everyCombination(
    WidgetTester tester,
    Widget Function() build,
  ) async {
    for (final device in _devices.entries) {
      for (final brightness in Brightness.values) {
        for (final scale in _scales) {
          tester.view.physicalSize = device.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _host(build(), brightness: brightness, scale: scale),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '${device.key} · ${brightness.name} · ${scale}x text scale',
          );
        }
      }
    }
  }

  testWidgets('a bar with no price lays out without throwing', (tester) async {
    await everyCombination(
      tester,
      () => StickyBottomBar(buttonText: 'Save changes', onPressed: () {}),
    );
  });

  testWidgets('a bar with no price gives the button the whole width',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      StickyBottomBar(buttonText: 'Save changes', onPressed: () {}),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Save changes'), findsOneWidget);

    final size = tester.getSize(find.byType(ElevatedButton));
    // 412 wide, less the bar's 20px padding on each side.
    expect(size.width, 412 - 40);
    expect(size.height, 52);
  });

  testWidgets('the button is tappable, not just painted', (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var taps = 0;
    await tester.pumpWidget(_host(
      StickyBottomBar(buttonText: 'Save changes', onPressed: () => taps++),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a loading bar shows a spinner and refuses the tap',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var taps = 0;
    await tester.pumpWidget(_host(
      StickyBottomBar(
        buttonText: 'Save changes',
        isLoading: true,
        onPressed: () => taps++,
      ),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
      reason: 'the in-flight flag is the double-submit guard',
    );

    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('a bar with a price still leaves room for both', (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      StickyBottomBar(
        price: '₹1,200',
        priceLabel: 'Total',
        buttonText: 'Confirm booking',
        onPressed: () {},
      ),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('₹1,200'), findsOneWidget);

    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.height, 52);
    // Sharing the row now, not taking all of it.
    expect(size.width, lessThan(412 - 40));
    expect(size.width, greaterThan(100));
  });
}
