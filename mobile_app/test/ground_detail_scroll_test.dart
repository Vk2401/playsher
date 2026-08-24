// Renders the real GroundDetailScreen against a seed-shaped ground and checks
// the two things the screenshot showed as broken: the title being painted
// under the hero image, and the page not scrolling.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/ground_model.dart';
import 'package:playsher_app/models/slot_model.dart';
import 'package:playsher_app/providers/grounds_provider.dart';
import 'package:playsher_app/screens/ground_detail_screen.dart';

/// Shaped like the row `GET /grounds/:id` returns for the seeded
/// "Green Valley Cricket Ground" (backend-api/database/seed.js).
GroundModel seededGround() => GroundModel.fromJson({
      'id': 1,
      'name': 'Green Valley Cricket Ground',
      // Without a venue price the booking bar correctly reads "not available".
      'price_per_slot': '250.00',
      'address': 'Block C, Gulberg III, Lahore',
      'city': 'Lahore',
      'description':
          'Professional cricket ground with well-maintained pitch and outfield. '
              'Ideal for club and friendly matches.',
      'about': "Lahore's premier cricket venue with day and night facilities.",
      'venue_rules':
          'No outside food. Studs allowed. Players must be in proper sportswear.',
      'images': [],
      'amenities': [
        {'id': 1, 'name': 'Parking'},
        {'id': 2, 'name': 'Floodlights'},
      ],
      'groundSports': [
        {
          'id': 10,
          'ground_id': 1,
          'price_per_half_hour': '2500',
          'sport': {'id': 1, 'name': 'Cricket'},
        },
        {
          'id': 11,
          'ground_id': 1,
          'price_per_half_hour': '800',
          'sport': {'id': 4, 'name': 'Badminton'},
        },
      ],
      'reviews': [],
    });

List<SlotModel> seededSlots() => SlotModel.listFromJson([
      {
        'id': 101,
        'slot_start_time': '18:00:00',
        'slot_end_time': '18:30:00',
        'is_available': true,
      },
      {
        'id': 102,
        'slot_start_time': '18:30:00',
        'slot_end_time': '19:00:00',
        'is_available': true,
      },
    ]);

Widget host({List<SlotModel>? slots}) => ProviderScope(
      overrides: [
        groundDetailProvider.overrideWith((ref, id) async => seededGround()),
        slotsProvider.overrideWith((ref, q) async => slots ?? const []),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const GroundDetailScreen(groundId: '1'),
      ),
    );

void main() {
  setUp(() {
    // Pixel-7-ish portrait, matching the reported screenshot.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('the ground name is visible, not painted under the hero image',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final title = find.text('Green Valley Cricket Ground');
    expect(title, findsOneWidget);

    final titleRect = tester.getRect(title);
    // The hero occupies expandedHeight from the top. If the title's top edge
    // sits above that boundary, it is being painted underneath the image.
    const heroBottom = 384.0;
    expect(
      titleRect.top,
      greaterThanOrEqualTo(heroBottom),
      reason: 'Title top ${titleRect.top} is above the hero bottom '
          '($heroBottom) — it renders under the image.',
    );
  });

  testWidgets('the page scrolls when the drag starts on the hero image',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final before = tester.getRect(find.text('About')).top;

    // Most of this screen is the hero, which hosts a horizontal PageView —
    // a vertical drag there must still scroll the page.
    await tester.dragFrom(const Offset(200, 180), const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final after = tester.getRect(find.text('About')).top;
    expect(after, lessThan(before),
        reason: 'Dragging on the hero image did not scroll the page.');
  });

  testWidgets('the page scrolls', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final scrollable = find.byType(Scrollable).first;
    final before = tester.getRect(find.text('About')).top;

    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final after = tester.getRect(find.text('About')).top;
    expect(after, lessThan(before),
        reason: 'Dragging up did not move the content: the page is stuck.');
  });

  testWidgets('a sport is selected on arrival, so slots are reachable',
      (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(slots: seededSlots()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Without a default selection the screen shows no slot picker at all and
    // the ground reads as unbookable.
    // SlotModel renders 18:00:00 as "6:00 PM".
    expect(find.text('6:00 PM'), findsWidgets,
        reason: 'No slots rendered — no sport was selected on arrival.');
  });

  testWidgets('selecting a slot reveals the booking bar', (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(slots: seededSlots()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Continue to Book'), findsNothing,
        reason: 'The bar should stay hidden until a slot is chosen.');

    await tester.tap(find.text('6:00 PM').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Continue to Book'), findsOneWidget,
        reason: 'Choosing a slot must surface the booking CTA.');
    // The bar names what is about to be booked, not just its price.
    expect(find.text('Selected Slot'), findsOneWidget);
    expect(find.textContaining('\u20b9'), findsWidgets);
  });
}
