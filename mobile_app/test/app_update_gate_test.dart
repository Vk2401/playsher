import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:playsher_app/models/app_version_model.dart';
import 'package:playsher_app/providers/app_version_provider.dart';
import 'package:playsher_app/router.dart';
import 'package:playsher_app/widgets/app_update_gate.dart';

/// Mirrors `app.dart`: the gate sits in `MaterialApp.router`'s `builder`, whose
/// context is above the router's navigator. Showing the dialog with that
/// context throws, so this is the tree the regression has to be pinned in.
///
/// `routerProvider` is overridden with the same router the app is driven by.
/// The gate reads the current path from that provider to decide where a nudge
/// is allowed, so a harness that built its own router separately would leave
/// the gate inspecting a router nobody is looking at — and the path rules
/// untested.
GoRouter buildTestRouter() => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/venues',
          builder: (_, __) => const Scaffold(body: Text('venues')),
        ),
      ],
    );

Widget host(AppVersionCheck check, {GoRouter? router}) {
  final r = router ?? buildTestRouter();
  return ProviderScope(
    overrides: [
      appVersionCheckProvider.overrideWith((_) async => check),
      routerProvider.overrideWithValue(r),
    ],
    child: MaterialApp.router(
      routerConfig: r,
      builder: (context, child) =>
          AppUpdateGate(child: child ?? const SizedBox()),
    ),
  );
}

const _optional = AppVersionCheck(
  updateAvailable: true,
  latestVersion: '1.0.19',
);

const _required = AppVersionCheck(
  updateAvailable: true,
  updateRequired: true,
  latestVersion: '2.0.0',
);

void main() {
  setUp(() {
    // A real cold start gets this for free by starting a new isolate; every
    // test here shares one, so the launch memory has to be cleared by hand.
    AppUpdateGate.resetLaunchState();
  });

  testWidgets('an optional update reaches the screen as a dialog',
      (tester) async {
    await tester.pumpWidget(host(_optional));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('a retired build is blocked with no way out', (tester) async {
    await tester.pumpWidget(host(_required));
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
  });

  testWidgets('a current build is never interrupted', (tester) async {
    await tester.pumpWidget(host(AppVersionCheck.none));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  // ── How often it prompts ──────────────────────────────────────────────────

  testWidgets('"Later" is respected: navigating does not raise it again',
      (tester) async {
    final router = buildTestRouter();
    await tester.pumpWidget(host(_optional, router: router));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);

    // The nag this replaces: a router listener re-raised the dialog on every
    // route change, so dismissing it bought nothing.
    router.go('/venues');
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing,
        reason: 'a dismissed nudge must not return when the user navigates');

    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing,
        reason: 'nor when the user comes back to home in the same launch');
  });

  testWidgets('an optional nudge never appears away from home', (tester) async {
    final router = buildTestRouter();
    router.go('/venues');

    await tester.pumpWidget(host(_optional, router: router));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsNothing,
        reason: 'a nudge on a detail screen interrupts whatever the user '
            'is doing there');
    expect(find.text('venues'), findsOneWidget);
  });

  testWidgets('a fresh launch prompts again', (tester) async {
    await tester.pumpWidget(host(_optional));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);

    // Clearing the app from recents and reopening it. Tearing the tree down
    // first is what makes it a *new* launch rather than a rebuild — the gate's
    // State is disposed, exactly as it would be when the process dies.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    AppUpdateGate.resetLaunchState();

    await tester.pumpWidget(host(_optional, router: buildTestRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget,
        reason: 'a genuinely fresh open should nudge once more');
  });

  testWidgets('a required update is not rate-limited and not home-only',
      (tester) async {
    final router = buildTestRouter();
    router.go('/venues');

    await tester.pumpWidget(host(_required, router: router));
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget,
        reason: 'a retired build must be blocked wherever the user is');
  });
}
