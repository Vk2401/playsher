// Layout and behaviour guards for the Games / Discover section.
//
// The card packs a sport rail, two meta lines, an avatar stack, a fill bar and
// a price/CTA footer into one column, so it is where a long venue name or a
// 1.3x text scale gives way first — and overflow is a paint-time error that
// `flutter analyze` cannot see.
//
// It also pins the rules the section is built on: the join button is a
// double-submit guard, a game the viewer is already in offers no button at
// all, and a filter sheet returns only what the player applied.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/game_filters.dart';
import 'package:playsher_app/models/game_model.dart';
import 'package:playsher_app/widgets/game_card.dart';
import 'package:playsher_app/widgets/game_filter_sheet.dart';
import 'package:playsher_app/widgets/player_stack.dart';

/// Pixel 7 and iPhone 14 logical sizes, per the guidelines' target devices.
const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};

const _scales = <double>[1.0, 1.3];

/// A game whose every field is as long as it plausibly gets.
Map<String, dynamic> _row({
  int seats = 10,
  int joined = 4,
  String status = 'open',
  bool isHost = false,
  bool isJoined = false,
  String? level = 'ultra_professional',
}) =>
    {
      'id': 7,
      'game_name': 'Sunday Morning Championship Five-a-side Football Fixture',
      'description': 'Bring bibs. We play 7-a-side and rotate every ten minutes.',
      'max_participants': seats,
      'joined_count': joined,
      'game_level': level,
      'visibility': 'public',
      'is_active': true,
      'status': status,
      'is_host': isHost,
      'is_joined': isJoined,
      'price_per_player': 187.5,
      'total_amount': 1875.0,
      'ground_name': 'Greenfield Sports Arena & Recreation Complex',
      'ground_area': 'Vasanth Nagar Main Road',
      'ground_city': 'Thiruvananthapuram District',
      'sport_name': 'Football',
      'slot_date': '2099-09-14',
      'slot_time_from': '18:00:00',
      'slot_time_to': '19:30:00',
      'host_name': 'Ramachandran Venkataraman Subramanian',
      'participants': List.generate(
        joined,
        (i) => {
          'id': i + 1,
          'user_id': i + 1,
          'status': 'joined',
          'user': {'id': i + 1, 'name': 'Player Number ${i + 1}'},
        },
      ),
    };

GameModel _game({
  int seats = 10,
  int joined = 4,
  String status = 'open',
  bool isHost = false,
  bool isJoined = false,
  String? level = 'ultra_professional',
}) =>
    GameModel.fromJson(_row(
      seats: seats,
      joined: joined,
      status: status,
      isHost: isHost,
      isJoined: isJoined,
      level: level,
    ));

Widget _host(
  Widget child, {
  required Brightness brightness,
  required double scale,
}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Center(child: child)),
      ),
    );

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

  // ── Layout ─────────────────────────────────────────────────────────────────

  testWidgets('GameCard does not overflow', (tester) async {
    await everyCombination(
      tester,
      () => SizedBox(width: 372, child: GameCard(game: _game(), onJoin: () {})),
    );
  });

  testWidgets('GameCard does not overflow on its last seat', (tester) async {
    // The urgency pill and the amber seat line only appear here, so this is a
    // different layout from the roomy card above.
    await everyCombination(
      tester,
      () => SizedBox(
        width: 372,
        child: GameCard(game: _game(seats: 10, joined: 9), onJoin: () {}),
      ),
    );
  });

  testWidgets('GameCard does not overflow with no price and no level',
      (tester) async {
    await everyCombination(tester, () {
      final row = _row(level: null)
        ..remove('price_per_player')
        ..remove('total_amount');
      return SizedBox(
        width: 372,
        child: GameCard(game: GameModel.fromJson(row), onJoin: () {}),
      );
    });
  });

  testWidgets('GameCard does not overflow for a game the viewer is in',
      (tester) async {
    // The button is replaced by a wider "You're in" state pill.
    await everyCombination(
      tester,
      () => SizedBox(
        width: 372,
        child: GameCard(game: _game(isJoined: true)),
      ),
    );
  });

  testWidgets('PlayerStack does not overflow with a full squad',
      (tester) async {
    await everyCombination(
      tester,
      () => SizedBox(
        width: 200,
        child: PlayerStack(
          players: _game(seats: 20, joined: 18).participants,
          emptySlots: 2,
        ),
      ),
    );
  });

  // ── The card's one action ──────────────────────────────────────────────────

  testWidgets('the join button reaches the 44px touch-target minimum',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      SizedBox(width: 372, child: GameCard(game: _game(), onJoin: () {})),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.widgetWithText(ElevatedButton, 'Join'));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('a joining card cannot be submitted twice', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      SizedBox(
        width: 372,
        child: GameCard(
          game: _game(),
          isJoining: true,
          onJoin: () => taps++,
        ),
      ),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pump();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull,
        reason: 'the in-flight flag must disable the control, not just spin');

    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('a game the viewer already joined offers no join button',
      (tester) async {
    await tester.pumpWidget(_host(
      SizedBox(width: 372, child: GameCard(game: _game(isJoined: true))),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Join'), findsNothing);
    expect(find.text("You're in"), findsOneWidget);
  });

  testWidgets('a hosted game says so instead of offering a seat',
      (tester) async {
    await tester.pumpWidget(_host(
      SizedBox(width: 372, child: GameCard(game: _game(isHost: true))),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Join'), findsNothing);
    expect(find.text("You're hosting"), findsOneWidget);
  });

  testWidgets('a played game shows its state, never a dead button',
      (tester) async {
    await tester.pumpWidget(_host(
      SizedBox(
        width: 372,
        child: GameCard(game: _game(status: 'completed'), onJoin: () {}),
      ),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('Played'), findsWidgets);
  });

  testWidgets('the seat count is stated in words, not colour alone',
      (tester) async {
    await tester.pumpWidget(_host(
      SizedBox(
        width: 372,
        child: GameCard(game: _game(seats: 10, joined: 9), onJoin: () {}),
      ),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Last spot'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);
    expect(find.text('9/10'), findsOneWidget);
  });

  // ── The filter sheet ───────────────────────────────────────────────────────

  /// The sheet is a full form — on the default 800x600 test surface its lower
  /// groups sit under the pinned button. Every sheet test runs at a phone size.
  void phoneSized(WidgetTester tester) {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the filter sheet returns what was applied, not what was tapped',
      (tester) async {
    phoneSized(tester);
    GameFilters? applied;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                applied = await GameFilterSheet.show(
                  context,
                  initial: const GameFilters(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Tomorrow'));
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Beginner'));
    await tester.tap(find.text('Beginner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show games'));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
    expect(applied!.when, GameWhen.tomorrow);
    expect(applied!.level, GameLevel.beginner);
  });

  testWidgets('a dismissed filter sheet changes nothing', (tester) async {
    phoneSized(tester);
    GameFilters? applied;
    var returned = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                applied = await GameFilterSheet.show(
                  context,
                  initial: const GameFilters(),
                );
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Weekend'));
    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();

    // Tapping the scrim above the sheet, the way dismissing it outside does.
    await tester.tapAt(const Offset(206, 40));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(applied, isNull,
        reason: 'a dismissed sheet must not leak half-made changes');
  });

  testWidgets('the filter sheet opens on what is already applied',
      (tester) async {
    phoneSized(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => GameFilterSheet.show(
                context,
                initial: const GameFilters(
                  when: GameWhen.weekend,
                  level: GameLevel.advanced,
                  onlyOpen: true,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('3 active'), findsOneWidget);
  });
}
