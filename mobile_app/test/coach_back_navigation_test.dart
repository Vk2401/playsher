// Every coach screen must offer a way back, including when it was reached with
// `context.go` — which replaces the whole stack, so `AppBar`'s automatic
// leading never appears. My Coaching shipped without one: after cancelling a
// session the only way off the screen was to close the app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/coach_booking_model.dart';
import 'package:playsher_app/models/coach_model.dart';
import 'package:playsher_app/providers/coach_bookings_provider.dart';
import 'package:playsher_app/providers/coaches_provider.dart';
import 'package:playsher_app/screens/coach_detail_screen.dart';
import 'package:playsher_app/screens/coach_session_detail_screen.dart';
import 'package:playsher_app/screens/coach_sessions_screen.dart';
import 'package:playsher_app/widgets/app_back_button.dart';

CoachBookingModel _session() => CoachBookingModel.fromJson({
      'id': 55,
      'coach_id': 9,
      'session_date': '2026-08-27',
      'time_from': '10:00:00',
      'time_to': '11:00:00',
      'total_amount': '1000.00',
      'status': 'cancelled',
      'coach': {'id': 9, 'name': 'Coach Tariq'},
      'ground': {'id': 3, 'name': 'Green Valley Cricket Ground'},
    });

CoachModel _coach() => CoachModel.fromJson({
      'id': 9,
      'name': 'Coach Tariq',
      'price_per_slot': '500.00',
      'groundLinks': const [],
    });

/// Hosts [screen] at [path] as the *only* route reached with `go`, which is the
/// state the bug appeared in: nothing on the stack to pop back to.
Widget _goneTo(String path, Widget screen) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Center(child: Text('home'))),
      ),
      GoRoute(
        path: '/coaching',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('coaching'))),
      ),
      GoRoute(
        path: '/my-sessions',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('my sessions'))),
      ),
      GoRoute(path: path, builder: (_, __) => screen),
    ],
  );
  // Replace the stack, exactly as the session screen's close control used to.
  router.go(path);
  return ProviderScope(
    overrides: [
      coachBookingsProvider.overrideWith((ref) async => [_session()]),
      coachBookingDetailProvider.overrideWith((ref, id) async => _session()),
      coachDetailProvider.overrideWith((ref, id) async => _coach()),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

void main() {
  Future<void> expectsWayBack(
    WidgetTester tester,
    String path,
    Widget screen,
    String lands,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_goneTo(path, screen));
    await tester.pumpAndSettle();

    final back = find.byType(AppBackButton);
    expect(back, findsOneWidget, reason: '$path has no back control');

    // 48px is IconButton's default, comfortably over the 44px minimum the
    // mobile UI guidelines set for any tappable.
    expect(tester.getSize(back).shortestSide,
        greaterThanOrEqualTo(44.0), reason: '$path back target is too small');

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text(lands), findsOneWidget,
        reason: '$path back control led nowhere');
  }

  testWidgets('My coaching falls back home when nothing is on the stack',
      (tester) async {
    await expectsWayBack(
        tester, '/my-sessions-test', const CoachSessionsScreen(), 'home');
  });

  testWidgets('a session falls back to My coaching', (tester) async {
    await expectsWayBack(tester, '/coach-sessions-test',
        const CoachSessionDetailScreen(sessionId: '55'), 'my sessions');
  });

  testWidgets('a coach page falls back to the coaching tab', (tester) async {
    await expectsWayBack(tester, '/coaching-test',
        const CoachDetailScreen(coachId: '9'), 'coaching');
  });
}
