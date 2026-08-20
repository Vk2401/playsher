// Back behaviour inside the tab shell, and the profile edit screen's rules.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/screens/main_shell.dart';

/// A miniature shell with the same branch layout the app uses.
Widget shellApp() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          for (final name in ['home', 'venues', 'games', 'coaching', 'profile'])
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/$name',
                builder: (_, __) => Scaffold(body: Center(child: Text('tab:$name'))),
              ),
            ]),
        ],
      ),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  );
}

/// Fires the Android system back button.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('back from another tab returns to Home, not out of the app',
      (tester) async {
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('GAMES'));
    await tester.pumpAndSettle();
    expect(find.text('tab:games'), findsOneWidget);

    await systemBack(tester);
    expect(find.text('tab:home'), findsOneWidget,
        reason: 'Back from a non-Home tab should land on Home.');
  });

  testWidgets('first back on Home warns instead of leaving', (tester) async {
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    await systemBack(tester);

    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(find.text('tab:home'), findsOneWidget,
        reason: 'The app must not close on the first press.');
  });

  testWidgets('a deep tab stack still resolves to Home first', (tester) async {
    await tester.pumpWidget(shellApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    await systemBack(tester);

    expect(find.text('tab:home'), findsOneWidget);
    // ...and only then does a press offer to exit.
    await systemBack(tester);
    expect(find.text('Press back again to exit'), findsOneWidget);
  });
}
