// Telling people apart, and telling notifications apart.
//
// Two defects sat behind one screenshot: a search that listed three different
// accounts as three identical rows, and a notification list where a new
// follower, a cancelled booking and a game invite all rendered as the same grey
// bell. Both are "the app has the information and does not show it".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/app_colors.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/notification_model.dart';
import 'package:playsher_app/models/player_model.dart';
import 'package:playsher_app/widgets/notification_card.dart';
import 'package:playsher_app/widgets/player_tile.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(body: child),
    );

PlayerCard _player({required int id, String? username}) => PlayerCard(
      id: id,
      name: 'Vasanth',
      username: username,
    );

NotificationModel _note(String type) => NotificationModel(
      id: type.hashCode & 0xffff,
      title: type,
      message: 'body',
      type: type,
      createdAt: DateTime(2026, 9, 13),
    );

/// The icon the card painted for this notification type.
Future<IconData> _iconFor(WidgetTester tester, String type) async {
  await tester.pumpWidget(_host(NotificationCard(notification: _note(type))));
  await tester.pumpAndSettle();
  // The leading glyph is the first Icon in the row; the unread dot is a box.
  final icon = tester.widget<Icon>(find.byType(Icon).first);
  return icon.icon!;
}

void main() {
  group('players with no handle', () {
    testWidgets('two accounts sharing a name still read as two people',
        (tester) async {
      await tester.pumpWidget(_host(Column(
        children: [
          PlayerTile(player: _player(id: 7)),
          PlayerTile(player: _player(id: 8)),
        ],
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The name appears twice — they really are both called Vasanth — but the
      // line underneath must not be a third and fourth copy of it.
      expect(find.text('Vasanth'), findsNWidgets(2));
      expect(find.text('Player #7'), findsOneWidget);
      expect(find.text('Player #8'), findsOneWidget);
    });

    testWidgets('a handle is shown when the account has one', (tester) async {
      await tester.pumpWidget(
        _host(PlayerTile(player: _player(id: 7, username: 'ravi99'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('@ravi99'), findsOneWidget);
      expect(find.text('Player #7'), findsNothing);
    });
  });

  group('notification kinds', () {
    testWidgets('a new follower does not look like a booking', (tester) async {
      final follow = await _iconFor(tester, 'player_followed');
      final booking = await _iconFor(tester, 'booking_created');
      final invite = await _iconFor(tester, 'game_invite');
      final coach = await _iconFor(tester, 'coach_booking_created');

      for (final pair in [
        [follow, booking],
        [follow, invite],
        [booking, coach],
        [invite, coach],
      ]) {
        expect(pair[0], isNot(pair[1]));
      }
    });

    testWidgets('none of the real types fall through to the generic bell',
        (tester) async {
      // Every type the API actually sends. The old map knew four names the
      // backend has never used, so all of these rendered identically.
      const real = [
        'booking_created',
        'booking_cancelled_by_owner',
        'booking_payment_collected',
        'coach_booking_confirmed',
        'coach_account_approved',
        'game_invite',
        'game_player_joined',
        'game_cancelled',
        'player_followed',
      ];

      for (final type in real) {
        final icon = await _iconFor(tester, type);
        expect(icon, isNot(Icons.notifications_rounded), reason: type);
      }

      // An unknown type still renders something rather than throwing.
      expect(
          await _iconFor(tester, 'something_new'), Icons.notifications_rounded);
    });

    testWidgets('anything cancelled or rejected is tinted as a problem',
        (tester) async {
      for (final type in [
        'booking_cancelled_by_customer',
        'game_cancelled',
        'coach_account_rejected',
      ]) {
        await tester
            .pumpWidget(_host(NotificationCard(notification: _note(type))));
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byType(Icon).first);
        expect(icon.color, AppColors.error, reason: type);
      }
    });

    testWidgets('lays out in both themes without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final brightness in Brightness.values) {
        await tester.pumpWidget(_host(
          NotificationCard(notification: _note('player_followed')),
          brightness: brightness,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: brightness.name);
      }
    });
  });
}
