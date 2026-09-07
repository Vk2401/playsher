// The edit screen has one committing action and one way to lose work, so both
// are pinned here.
//
// The Save button was invisible in the shipped build: `StickyBottomBar` forced
// an infinite width on any bar without a price (see sticky_bottom_bar_test),
// so this screen had no working way to save at all.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/user_model.dart';
import 'package:playsher_app/providers/auth_provider.dart';
import 'package:playsher_app/screens/edit_profile_screen.dart';

const _user = UserModel(
  id: 7,
  name: 'Ravi Kumar',
  username: 'ravi99',
  bio: 'Left wing',
  mobile: '+919876543210',
  email: 'ravi@example.com',
);

/// `AuthNotifier`'s constructor reads secure storage on the way up. Nothing is
/// stored in a test, so the channel is answered with nulls and the notifier
/// settles on "signed out" — which the stub then overrides with the fixture.
void _stubSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });
}

/// The screen behind a router, so `context.pop()` and the system back gesture
/// behave as they do in the app rather than as a bare Navigator.
Widget _host({required GlobalKey<NavigatorState> navKey}) {
  final router = GoRouter(
    navigatorKey: navKey,
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('PROFILE')),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, __) => const EditProfileScreen(),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => _StubAuth(ref)),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

class _StubAuth extends AuthNotifier {
  _StubAuth(super.ref) {
    // Set after super(), so the constructor's own storage read cannot win.
    state = const AuthState(user: _user);
  }

  /// The screen refreshes the account after saving; there is no API here.
  @override
  Future<void> refreshUser() async {}
}

Future<void> _openEditor(WidgetTester tester, GlobalKey<NavigatorState> k) async {
  _stubSecureStorage();
  await tester.pumpWidget(_host(navKey: k));
  await tester.pumpAndSettle();
  k.currentContext!.go('/profile/edit');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Save button is on screen and reachable', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = GlobalKey<NavigatorState>();
    await _openEditor(tester, k);

    expect(tester.takeException(), isNull);
    expect(find.text('Save changes'), findsOneWidget);

    final size = tester.getSize(find.byType(ElevatedButton).last);
    expect(size.height, greaterThanOrEqualTo(44),
        reason: 'a save button below the touch minimum is not a save button');
    expect(size.width, greaterThan(200),
        reason: 'it was collapsing to zero width before the bar was fixed');
  });

  testWidgets('Save is disabled until something actually changes',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = GlobalKey<NavigatorState>();
    await _openEditor(tester, k);

    ElevatedButton save() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
    expect(save().onPressed, isNull, reason: 'nothing edited yet');

    await tester.enterText(find.byType(TextFormField).first, 'Ravi K');
    await tester.pumpAndSettle();
    expect(save().onPressed, isNotNull);

    // Typing it back to the original leaves nothing to save.
    await tester.enterText(find.byType(TextFormField).first, 'Ravi Kumar');
    await tester.pumpAndSettle();
    expect(save().onPressed, isNull,
        reason: 'edited and undone is not a change');
  });

  group('leaving with unsaved changes', () {
    testWidgets('an untouched form closes without asking', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final k = GlobalKey<NavigatorState>();
      await _openEditor(tester, k);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Discard your changes?'), findsNothing);
      expect(find.text('PROFILE'), findsOneWidget);
    });

    testWidgets('the back arrow asks before discarding', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final k = GlobalKey<NavigatorState>();
      await _openEditor(tester, k);

      await tester.enterText(find.byType(TextFormField).first, 'Someone Else');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Discard your changes?'), findsOneWidget);
      expect(find.textContaining('will be lost'), findsOneWidget);
    });

    testWidgets('"Keep editing" stays put with the edit intact',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final k = GlobalKey<NavigatorState>();
      await _openEditor(tester, k);

      await tester.enterText(find.byType(TextFormField).first, 'Someone Else');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsNothing, reason: 'still on the editor');
      expect(find.text('Someone Else'), findsOneWidget,
          reason: 'the edit survives the question');
    });

    testWidgets('"Discard" leaves', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final k = GlobalKey<NavigatorState>();
      await _openEditor(tester, k);

      await tester.enterText(find.byType(TextFormField).first, 'Someone Else');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsOneWidget);
    });

    testWidgets('the system back gesture is guarded too', (tester) async {
      // A screen that only protects the arrow protects nothing — people leave
      // whichever way is nearest.
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final k = GlobalKey<NavigatorState>();
      await _openEditor(tester, k);

      await tester.enterText(find.byType(TextFormField).first, 'Someone Else');
      await tester.pumpAndSettle();

      // What the platform sends for a hardware/gesture back.
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec()
            .encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await tester.pumpAndSettle();

      expect(find.text('Discard your changes?'), findsOneWidget);
      expect(find.text('PROFILE'), findsNothing);
    });

    testWidgets('a changed bio also counts as unsaved work', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final k = GlobalKey<NavigatorState>();
      await _openEditor(tester, k);

      // Every field feeds the same question, not just the first one.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Left wing'), 'Right wing');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
    });
  });
}
