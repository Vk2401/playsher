// Finding somebody to follow used to be possible from exactly one place: the
// Invite button on a game you already hosted. A player who had never hosted
// could not search for anyone, and following depended on stumbling across a
// profile in a squad — the follow graph had no front door.
//
// These pin the door open: the screen exists, it opens on something actionable,
// it follows from the list, and the partial-number rule is explained here too.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/player_model.dart';
import 'package:playsher_app/providers/players_provider.dart';
import 'package:playsher_app/screens/find_players_screen.dart';
import 'package:playsher_app/widgets/player_search.dart';
import 'package:playsher_app/widgets/player_tile.dart';

const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};

PlayerCard _p(int id, String name, String username, {int? together}) =>
    PlayerCard(
        id: id, name: name, username: username, gamesTogether: together);

Widget _host({
  List<PlayerCard> teammates = const [],
  List<PlayerCard> results = const [],
  double scale = 1.0,
  Brightness brightness = Brightness.light,
}) =>
    ProviderScope(
      overrides: [
        teammatesProvider.overrideWith((ref) async => teammates),
        playerSearchProvider.overrideWith((ref, q) async => results),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const FindPlayersScreen(),
        ),
      ),
    );

void main() {
  void phone(WidgetTester tester, [String device = 'Pixel 7']) {
    tester.view.physicalSize = _devices[device]!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('opens on the people you have played with', (tester) async {
    phone(tester);
    await tester.pumpWidget(_host(teammates: [
      _p(1, 'Dev Sharma', 'dev_king', together: 4),
      _p(2, 'Anu Rao', 'anu_r', together: 1),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Find players'), findsOneWidget);
    expect(find.text('People you play with'), findsOneWidget);
    expect(find.text('Dev Sharma'), findsOneWidget);
    expect(find.text('@dev_king · 4 games together'), findsOneWidget);
  });

  testWidgets('every row offers a follow button', (tester) async {
    phone(tester);
    await tester.pumpWidget(_host(teammates: [
      _p(1, 'Dev Sharma', 'dev_king'),
      _p(2, 'Anu Rao', 'anu_r'),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(FollowButton), findsNWidgets(2));
    expect(find.text('Follow'), findsNWidgets(2));
  });

  testWidgets('searching swaps the list and its heading', (tester) async {
    phone(tester);
    await tester.pumpWidget(_host(
      teammates: [_p(1, 'Dev Sharma', 'dev_king')],
      results: [_p(9, 'Ravneet Singh', 'ravneet')],
    ));
    await tester.pumpAndSettle();
    expect(find.text('People you play with'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ravn');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Ravneet Singh'), findsOneWidget);
    expect(find.text('Dev Sharma'), findsNothing);
  });

  testWidgets('one character does not search — the API refuses it anyway',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_host(
      teammates: [_p(1, 'Dev Sharma', 'dev_king')],
      results: [_p(9, 'Ravneet Singh', 'ravneet')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'r');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('People you play with'), findsOneWidget);
    expect(find.text('Dev Sharma'), findsOneWidget);
  });

  testWidgets('clearing the field goes back to teammates', (tester) async {
    phone(tester);
    await tester.pumpWidget(_host(
      teammates: [_p(1, 'Dev Sharma', 'dev_king')],
      results: [_p(9, 'Ravneet Singh', 'ravneet')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ravn');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Ravneet Singh'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('People you play with'), findsOneWidget);
    expect(find.text('Dev Sharma'), findsOneWidget);
  });

  testWidgets('a partial number is explained, not reported as a miss',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '98765');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Enter the full 10-digit number'), findsOneWidget);
  });

  testWidgets('a player with no teammates is pointed at a game, not a dead end',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('No teammates yet'), findsOneWidget);
    expect(find.text('Find a game to join'), findsOneWidget,
        reason: 'you cannot search for a handle you do not know yet');
  });

  testWidgets('lays out without overflowing', (tester) async {
    for (final device in _devices.keys) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 1.3]) {
          phone(tester, device);
          await tester.pumpWidget(_host(
            teammates: [
              _p(1, 'Ramachandran Venkataraman Subramanian',
                  'ramachandran_venkataraman', together: 12),
            ],
            scale: scale,
            brightness: brightness,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$device · ${brightness.name} · ${scale}x');
        }
      }
    }
  });

  group('PlayerSearchEmpty.isPartialNumber', () {
    test('an incomplete number is partial', () {
      expect(PlayerSearchEmpty.isPartialNumber('98765'), isTrue);
      expect(PlayerSearchEmpty.isPartialNumber('987 650 00'), isTrue);
      expect(PlayerSearchEmpty.isPartialNumber('+91 98765'), isTrue);
    });

    test('a complete number is not', () {
      expect(PlayerSearchEmpty.isPartialNumber('9876500001'), isFalse);
      expect(PlayerSearchEmpty.isPartialNumber('+919876500001'), isFalse);
    });

    test('a handle is never treated as a number', () {
      expect(PlayerSearchEmpty.isPartialNumber('ravi99'), isFalse);
      expect(PlayerSearchEmpty.isPartialNumber('dev_king'), isFalse);
      expect(PlayerSearchEmpty.isPartialNumber(''), isFalse);
    });
  });
}
