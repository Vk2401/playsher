// Layout and behaviour guards for the social surfaces: the player tile, the
// follow button and the invite sheet.
//
// Two rules are pinned as behaviour rather than as comments, because they are
// the ones that would break quietly: a follow button never appears on your own
// row, and a partial phone number is explained rather than left looking like
// "your friend isn't on Playsher".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/player_model.dart';
import 'package:playsher_app/providers/players_provider.dart';
import 'package:playsher_app/widgets/invite_players_sheet.dart';
import 'package:playsher_app/widgets/player_tile.dart';

const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};
const _scales = <double>[1.0, 1.3];

PlayerCard _player({
  int id = 7,
  String name = 'Ramachandran Venkataraman Subramanian',
  String? username = 'ramachandran_venkataraman',
  bool following = false,
  bool isSelf = false,
  int? together,
}) =>
    PlayerCard(
      id: id,
      name: name,
      username: username,
      isFollowing: following,
      isSelf: isSelf,
      gamesTogether: together,
    );

Widget _host(
  Widget child, {
  required Brightness brightness,
  required double scale,
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: Center(child: child)),
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

  // ── Layout ─────────────────────────────────────────────────────────────────

  testWidgets('PlayerTile does not overflow with a follow button',
      (tester) async {
    await everyCombination(
      tester,
      () => SizedBox(
        width: 372,
        child: PlayerTile(
          player: _player(),
          trailing: const FollowButton(playerId: 7, isFollowing: false),
        ),
      ),
    );
  });

  testWidgets('PlayerTile does not overflow showing games together',
      (tester) async {
    await everyCombination(
      tester,
      () => SizedBox(
        width: 372,
        child: PlayerTile(
          player: _player(together: 12),
          trailing: const FollowButton(playerId: 7, isFollowing: true),
        ),
      ),
    );
  });

  // ── The follow button ──────────────────────────────────────────────────────

  testWidgets('a follow button never appears on your own row', (tester) async {
    await tester.pumpWidget(_host(
      SizedBox(
        width: 372,
        child: PlayerTile(
          player: _player(isSelf: true),
          trailing: const FollowButton(
              playerId: 7, isFollowing: false, isSelf: true),
        ),
      ),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('the button states its relationship in words', (tester) async {
    await tester.pumpWidget(_host(
      const SizedBox(
          width: 372, child: FollowButton(playerId: 7, isFollowing: false)),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Follow'), findsOneWidget);

    await tester.pumpWidget(_host(
      const SizedBox(
          width: 372, child: FollowButton(playerId: 7, isFollowing: true)),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('the follow button meets the 44px touch-target minimum',
      (tester) async {
    await tester.pumpWidget(_host(
      const SizedBox(
          width: 372, child: FollowButton(playerId: 7, isFollowing: false)),
      brightness: Brightness.light,
      scale: 1.0,
    ));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  // ── The invite sheet ───────────────────────────────────────────────────────

  Widget inviteHost({
    required List<PlayerCard> teammates,
    Set<int> alreadyInvolved = const {},
  }) =>
      ProviderScope(
        overrides: [
          teammatesProvider.overrideWith((ref) async => teammates),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: InvitePlayersSheet(
              gameId: 1,
              gameName: 'Sunday 5-a-side',
              alreadyInvolved: alreadyInvolved,
            ),
          ),
        ),
      );

  testWidgets('the invite sheet opens on people you have played with',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inviteHost(teammates: [
      _player(id: 1, name: 'Dev Sharma', username: 'dev_king', together: 4),
      _player(id: 2, name: 'Anu Rao', username: 'anu_r', together: 1),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('People you play with'), findsOneWidget);
    expect(find.text('Dev Sharma'), findsOneWidget);
    expect(find.text('@dev_king · 4 games together'), findsOneWidget);
    // Nothing picked yet, so there is nothing to send.
    expect(find.text('Pick players to invite'), findsOneWidget);
  });

  testWidgets('picking players arms the send button', (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inviteHost(teammates: [
      _player(id: 1, name: 'Dev Sharma', username: 'dev_king'),
      _player(id: 2, name: 'Anu Rao', username: 'anu_r'),
    ]));
    await tester.pumpAndSettle();

    final send = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Pick players to invite'),
    );
    expect(send.onPressed, isNull, reason: 'nothing selected yet');

    await tester.tap(find.text('Dev Sharma'));
    await tester.pumpAndSettle();
    expect(find.text('Invite 1'), findsOneWidget);

    await tester.tap(find.text('Anu Rao'));
    await tester.pumpAndSettle();
    expect(find.text('Invite 2'), findsOneWidget);

    // Tapping again puts one back.
    await tester.tap(find.text('Anu Rao'));
    await tester.pumpAndSettle();
    expect(find.text('Invite 1'), findsOneWidget);
  });

  testWidgets('players already in the game cannot be picked twice',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inviteHost(
      teammates: [_player(id: 1, name: 'Dev Sharma', username: 'dev_king')],
      alreadyInvolved: {1},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Already in'), findsOneWidget);
    await tester.tap(find.text('Dev Sharma'));
    await tester.pumpAndSettle();
    // Still nothing selected.
    expect(find.text('Pick players to invite'), findsOneWidget);
  });

  testWidgets('an empty teammate list explains itself', (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(inviteHost(teammates: const []));
    await tester.pumpAndSettle();

    expect(find.text('No teammates yet'), findsOneWidget);
  });

  testWidgets('a partial phone number says so rather than "not found"',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        teammatesProvider.overrideWith((ref) async => const []),
        playerSearchProvider.overrideWith((ref, q) async => const []),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: InvitePlayersSheet(gameId: 1, gameName: 'Sunday 5-a-side'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '98765');
    // Past the 350ms debounce.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Enter the full 10-digit number'), findsOneWidget);
    expect(
      find.textContaining('A mobile number has to be complete'),
      findsOneWidget,
      reason: 'a partial number must not read as "your friend is not here"',
    );
  });

  testWidgets('a real miss reads as a miss, not as a malformed number',
      (tester) async {
    tester.view.physicalSize = _devices['Pixel 7']!;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        teammatesProvider.overrideWith((ref) async => const []),
        playerSearchProvider.overrideWith((ref, q) async => const []),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: InvitePlayersSheet(gameId: 1, gameName: 'Sunday 5-a-side'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nobody_here');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Nobody matched that'), findsOneWidget);
  });
}
