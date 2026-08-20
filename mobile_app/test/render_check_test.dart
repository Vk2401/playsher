// Renders the widgets that carry fixed heights or unflexed Rows across the
// device sizes, brightnesses and text scales the mobile UI guidelines require,
// and fails on any RenderFlex overflow.
//
// This is a regression guard for the layout defects fixed alongside it, not a
// general test suite: overflow is a paint-time error that `flutter analyze`
// cannot see.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/app_colors.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/ground_model.dart';
import 'package:playsher_app/models/slot_model.dart';
import 'package:playsher_app/widgets/ground_card.dart';
import 'package:playsher_app/widgets/slot_tile.dart';
import 'package:playsher_app/widgets/status_badge.dart';
import 'package:playsher_app/widgets/sticky_bottom_bar.dart';

/// Pixel 7 and iPhone 14 logical sizes, per the guidelines' target devices.
const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};

const _scales = <double>[1.0, 1.3];

/// Mirrors the height formula `home_screen.dart` uses for the featured
/// carousel. Kept in step with it deliberately: the bug was a constant here.
double _carouselHeight(double scale) => 236 * (scale > 1.4 ? 1.4 : scale);

GroundModel _ground() => GroundModel.fromJson({
      'id': 1,
      // Deliberately long: the values that used to overflow the fixed-width card.
      'name': 'Greenfield Sports Arena & Recreation Complex',
      'city': 'Thiruvananthapuram District, Kerala, South India',
      'address': '4th Floor, Vasanth Nagar Main Road, Bengaluru',
      'average_rating': 4.8,
      'review_count': 128,
      'price_per_slot': '12500',
      'amenities': [
        {'id': 1, 'name': 'Floodlights'},
        {'id': 2, 'name': 'Changing Rooms'},
        {'id': 3, 'name': 'Parking Available'},
        {'id': 4, 'name': 'Drinking Water'},
      ],
      'ground_sports': [],
      'images': [],
      'reviews': [],
    });

SlotModel _slot() => SlotModel.fromJson({
      'id': 1,
      'start_time': '18:00:00',
      'end_time': '19:00:00',
      'is_available': true,
    });

Widget _host(Widget child,
    {required Brightness brightness, required double scale}) {
  // GroundCard reads the user's position from `userLocationProvider` to show
  // "how far away", so every host needs a scope. The real notifier is fine
  // here: with no location plugin registered it settles on "no fix", which is
  // the layout case where the distance badge is absent.
  return ProviderScope(
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  /// Runs [build] across both devices, both brightnesses and both text scales.
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
          // MaterialApp lerps theme changes through AnimatedTheme; without
          // settling, a brightness swap still paints the previous theme.
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

  testWidgets('GroundCard (list layout) does not overflow', (tester) async {
    await everyCombination(
      tester,
      () => SizedBox(
        width: 380,
        child: GroundCard(
          ground: _ground(),
          isFavorite: true,
          onFavoriteToggle: () {},
        ),
      ),
    );
  });

  testWidgets('GroundCard (featured layout) does not overflow', (tester) async {
    await everyCombination(
      tester,
      () => SizedBox(
        // The home carousel's height, scaled the way the screen scales it.
        height: _carouselHeight(1.3),
        child: GroundCard(
          ground: _ground(),
          wide: true,
          onFavoriteToggle: () {},
        ),
      ),
    );
  });

  // The defect this guards: the featured carousel used a hard 280px height,
  // which fits at the default text scale — why it shipped — but clipped the
  // price at 1.3x. The card is now built around an `Expanded` image, so a
  // short slot shortens the photo instead of clipping the text. This pins
  // that property: squeeze the card well below its designed height, at the
  // largest text scale, and it must still lay out cleanly.
  testWidgets('featured card absorbs a short slot instead of overflowing',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final height in [280.0, 200.0, _carouselHeight(1.3)]) {
      await tester.pumpWidget(_host(
        SizedBox(
          height: height,
          child: GroundCard(
              ground: _ground(), wide: true, onFavoriteToggle: () {}),
        ),
        brightness: Brightness.dark,
        scale: 1.3,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'at ${height}px tall');
    }
  });

  testWidgets('StickyBottomBar does not overflow with a long price',
      (tester) async {
    await everyCombination(
      tester,
      () => const StickyBottomBar(
        priceLabel: 'Total amount payable',
        price: '₹1,24,500',
        buttonText: 'Confirm and pay now',
      ),
    );
  });

  testWidgets('SlotTile does not overflow', (tester) async {
    await everyCombination(
      tester,
      () => SlotTile(slot: _slot(), selected: true, onTap: () {}),
    );
  });

  testWidgets('StatusBadge does not overflow', (tester) async {
    await everyCombination(
      tester,
      () => SizedBox(
        width: 120,
        child: StatusBadge.bookingStatus('cancelled'),
      ),
    );
  });

  testWidgets('favourite control meets the 44px touch-target minimum',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      SizedBox(
        width: 380,
        child: GroundCard(ground: _ground(), onFavoriteToggle: () {}),
      ),
      brightness: Brightness.dark,
      scale: 1.0,
    ));
    await tester.pump();

    final target = find.bySemanticsLabel('Save this ground');
    expect(target, findsOneWidget);

    final size = tester.getSize(target);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} theme resolves distinct surface tokens',
        (tester) async {
      late AppColors resolved;
      await tester.pumpWidget(_host(
        Builder(builder: (context) {
          resolved = context.colors;
          return const SizedBox();
        }),
        brightness: brightness,
        scale: 1.0,
      ));
      await tester.pumpAndSettle();

      final expected =
          brightness == Brightness.dark ? AppColors.dark : AppColors.light;
      expect(resolved.background, expected.background);
      expect(resolved.textPrimary, expected.textPrimary);

      // The regression this guards: the auth screens drew AppTheme.textPrimary
      // (white) on a hard-coded white Scaffold, so the text was invisible.
      expect(resolved.textPrimary, isNot(resolved.background));
      expect(resolved.textSecondary, isNot(resolved.background));
      expect(resolved.textPrimary, isNot(resolved.card));
    });
  }
}
