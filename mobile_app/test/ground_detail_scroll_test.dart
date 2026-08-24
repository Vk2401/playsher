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
          'max_slots': 2,
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
      {
        'id': 103,
        'slot_start_time': '19:00:00',
        'slot_end_time': '19:30:00',
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

  testWidgets('the venue\'s per-booking cap is enforced before checkout',
      (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(slots: seededSlots()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The seeded ground-sport takes two slots per booking, and says so.
    expect(find.text('Up to 2 slots per booking'), findsOneWidget);

    // A time appears twice — as one card's end and the next one's start — so
    // .last is the card that *starts* then, which is the one being picked.
    await tester.tap(find.text('6:00 PM').first);
    await tester.pump();
    await tester.tap(find.text('6:30 PM').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('2 slots'), findsWidgets);

    // The third is refused, and refused *visibly* — a silent no-op reads as a
    // dead tap, and letting it through only moves the refusal to the server.
    await tester.tap(find.text('7:00 PM').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('takes up to 2 slots'), findsOneWidget);
    expect(find.textContaining('3 slots'), findsNothing);
  });

  testWidgets('an empty period says so instead of bouncing back',
      (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Evening-only slots, so Night is empty.
    await tester.pumpWidget(host(slots: seededSlots()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Night'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // It used to fall back to the first period with slots, so tapping Night
    // left Evening highlighted and evening slots on screen.
    expect(find.textContaining('No slots left this night'), findsOneWidget);
    expect(find.text('6:00 PM'), findsNothing);
  });

  testWidgets('the slot row can be paged with the arrows', (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Enough slots to overflow the row, so there is something to page to.
    await tester.pumpWidget(host(
      slots: SlotModel.listFromJson([
        for (var i = 0; i < 10; i++)
          {
            'id': 200 + i,
            'slot_start_time':
                '${(18 + i ~/ 2).toString().padLeft(2, '0')}:${i.isEven ? '00' : '30'}:00',
            'slot_end_time':
                '${(18 + (i + 1) ~/ 2).toString().padLeft(2, '0')}:${i.isEven ? '30' : '00'}:00',
            'is_available': true,
          },
      ]),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Live on arrival. On the frame the row is built the controller has no
    // clients, so the arrow starts disabled — and with nothing able to scroll
    // the row, no scroll notification would ever arrive to enable it.
    IconButton forwardArrow() => tester
        .widgetList<IconButton>(find.byType(IconButton))
        .firstWhere((b) => b.tooltip == 'Later slots');

    // Live on the first frame the row is on screen — no scroll, no extra
    // pump. It used to depend on a scroll notification to enable itself,
    // which meant it only worked once you had already scrolled by hand.
    expect(forwardArrow().onPressed, isNotNull,
        reason: 'the forward arrow must work without scrolling first');

    expect(find.text('6:00 PM'), findsWidgets);
    await tester.tap(find.byTooltip('Later slots'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The earliest slot has scrolled out of the row entirely.
    expect(find.text('6:00 PM'), findsNothing,
        reason: 'the arrow did not move the row');
  });

  // Switching period used to carry the previous row's scroll offset into the
  // new one: the row opened halfway along, and the arrows greyed against a
  // length that no longer existed. Each period now measures its own row.
  testWidgets('switching period starts its row at the beginning',
      (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Ten in the morning and ten in the evening, so either row overflows.
    await tester.pumpWidget(host(
      slots: SlotModel.listFromJson([
        for (final base in [6, 18])
          for (var i = 0; i < 10; i++)
            {
              'id': base * 100 + i,
              'slot_start_time':
                  '${(base + i ~/ 2).toString().padLeft(2, '0')}:${i.isEven ? '00' : '30'}:00',
              'slot_end_time':
                  '${(base + (i + 1) ~/ 2).toString().padLeft(2, '0')}:${i.isEven ? '30' : '00'}:00',
              'is_available': true,
            },
      ]),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Morning opens first, and pages away from its earliest slot.
    expect(find.text('6:00 AM'), findsWidgets);
    await tester.tap(find.byTooltip('Later slots'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('6:00 AM'), findsNothing);

    await tester.tap(find.text('Evening'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    IconButton backArrow() => tester
        .widgetList<IconButton>(find.byType(IconButton))
        .firstWhere((b) => b.tooltip == 'Earlier slots');

    expect(find.text('6:00 PM'), findsWidgets,
        reason: 'the evening row must open on its first slot');
    expect(backArrow().onPressed, isNull,
        reason: 'a row at its start has nothing earlier to page to');
  });
}
