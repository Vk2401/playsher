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
Widget host(AppVersionCheck check) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
    ],
  );

  return ProviderScope(
    overrides: [
      appVersionCheckProvider.overrideWith((_) async => check),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) =>
          AppUpdateGate(child: child ?? const SizedBox()),
    ),
  );
}

void main() {
  testWidgets('an optional update reaches the screen as a dialog',
      (tester) async {
    await tester.pumpWidget(host(const AppVersionCheck(
      updateAvailable: true,
      latestVersion: '1.0.19',
      updateUrl: 'https://play.google.com/store/apps/details?id=com.playsher',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('a retired build is blocked with no way out', (tester) async {
    await tester.pumpWidget(host(const AppVersionCheck(
      updateAvailable: true,
      updateRequired: true,
      latestVersion: '2.0.0',
    )));
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
}
