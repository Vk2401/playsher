// Logging out has to leave nothing of the account behind.
//
// The bug this covers: dropping the tokens is not enough. Riverpod holds a
// resolved provider's value for the life of the process, so the caches that
// answered personalised requests still held the previous user's rows — sign in
// with a different number and the old name, bookings and favourites were still
// on screen, which reads as having been logged into the wrong account. The
// account's city lived in SharedPreferences and survived too.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/providers/auth_provider.dart';
import 'package:playsher_app/providers/city_provider.dart';
import 'package:playsher_app/providers/favorites_provider.dart';
import 'package:playsher_app/providers/notifications_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// flutter_secure_storage is a plugin, so the channel has to be stood up by
/// hand — an in-memory map behaves exactly as the real one does for the reads
/// and deletes this exercises.
Map<String, String> _fakeSecureStorage() {
  final store = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    switch (call.method) {
      case 'write':
        store[args['key'] as String] = args['value'] as String;
        return null;
      case 'read':
        return store[args['key'] as String];
      case 'readAll':
        return store;
      case 'delete':
        store.remove(args['key'] as String);
        return null;
      case 'deleteAll':
        store.clear();
        return null;
      case 'containsKey':
        return store.containsKey(args['key'] as String);
    }
    return null;
  });

  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;

  setUp(() {
    secure = _fakeSecureStorage();
    SharedPreferences.setMockInitialValues({
      // The signed-in account's choices…
      'user_city': 'Chennai',
      'last_latitude': 13.08,
      'last_longitude': 80.27,
      // …and the phone's own, which must survive.
      'theme_mode': 'dark',
      'onboarding_seen': true,
    });
  });

  test('logging out clears the tokens and the cached profile', () async {
    secure
      ..['access_token'] = 'a-token'
      ..['refresh_token'] = 'r-token'
      ..['user_data'] = '{"id":1,"name":"First User"}';

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).logout();

    expect(secure, isEmpty, reason: 'secure storage must be emptied');
    expect(container.read(authProvider).user, isNull);
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  test('logging out drops the account preferences but not the device ones',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.notifier).logout();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_city'), isNull);
    expect(prefs.getDouble('last_latitude'), isNull);
    expect(prefs.getDouble('last_longitude'), isNull);

    // The handset is still the same handset.
    expect(prefs.getString('theme_mode'), 'dark');
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  test('logging out discards the caches the account filled', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Resolve some user-scoped providers, as any screen would.
    final favouritesBefore = container.read(favoritesProvider.notifier);
    final notificationsBefore = container.read(notificationsProvider.notifier);
    container.read(cityProvider);
    // Let the city read off the disk settle, so this is a filled cache rather
    // than an empty one that would pass either way.
    await Future<void>.delayed(Duration.zero);
    expect(container.read(cityProvider), 'Chennai');

    await container.read(authProvider.notifier).logout();

    // A fresh notifier means the previous user's rows are gone rather than
    // being handed to whoever signs in next.
    expect(
      identical(container.read(favoritesProvider.notifier), favouritesBefore),
      isFalse,
      reason: 'favourites must not survive a logout',
    );
    expect(
      identical(
          container.read(notificationsProvider.notifier), notificationsBefore),
      isFalse,
      reason: 'notifications must not survive a logout',
    );
    expect(
      container.read(cityProvider),
      isNull,
      reason: "the next user must not inherit the last one's city",
    );
  });
}
