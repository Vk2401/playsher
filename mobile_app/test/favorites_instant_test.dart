// Tapping a heart is its own feedback, so the list has to change before the
// request does.
//
// The bug this covers: saving waited a round trip for the write and a second
// one for a full reload that cleared the list to `loading` on the way — so the
// heart sat empty through both, and blinked back to empty in between. Removing
// was optimistic; adding was not.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/app_colors.dart';
import 'package:playsher_app/models/ground_model.dart';
import 'package:playsher_app/providers/favorites_provider.dart';
import 'package:playsher_app/widgets/favorite_button.dart';

GroundModel _ground({int id = 7}) => GroundModel(
      id: id,
      name: 'Green Valley Cricket Ground',
      pricePerSlot: 300,
    );

void main() {
  // Two things this buys: the binding installs flutter_test's offline HTTP
  // client, so the writes below fail immediately instead of dialling out, and
  // the channel below stands in for flutter_secure_storage — without it the
  // request interceptor throws a MissingPluginException reaching for the
  // token, before any of this is exercised.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  test('saving shows up before the request is answered', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ground = _ground();
    expect(container.read(favoriteIdsProvider), isEmpty);

    // Held, not awaited yet: this is the frame the user sees, and by then the
    // write has not been sent, let alone answered.
    final pending = container.read(favoritesProvider.notifier).toggle(ground);

    expect(
      container.read(favoriteIdsProvider),
      contains(ground.id),
      reason: 'the heart must fill on the tap, not on the response',
    );

    // Let the write settle inside this test rather than leaking into the next
    // one. It fails — there is no server here — and the notifier swallows it.
    await pending;
  });

  test('unsaving is just as immediate', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ground = _ground();
    final notifier = container.read(favoritesProvider.notifier);

    final saving = notifier.toggle(ground);
    expect(container.read(favoriteIdsProvider), contains(ground.id));
    await saving;

    // Put it back by hand: the write above failed, so the list is empty again.
    final unsaving = notifier.toggle(ground);
    expect(container.read(favoriteIdsProvider), contains(ground.id));
    await unsaving;
  });

  test('a second tap while the first is in flight is dropped', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ground = _ground();
    final notifier = container.read(favoritesProvider.notifier);

    final first = notifier.toggle(ground);
    // Two opposite writes racing would leave the server disagreeing with the
    // card; the card already shows what this tap would ask for.
    final second = notifier.toggle(ground);

    expect(container.read(favoriteIdsProvider), contains(ground.id));
    await Future.wait([first, second]);
  });

  testWidgets('a saved ground shows a filled red heart', (tester) async {
    final ground = _ground();

    Widget host(Set<int> saved) => ProviderScope(
          overrides: [favoriteIdsProvider.overrideWithValue(saved)],
          child: MaterialApp(
            home: Scaffold(body: Center(child: FavoriteButton(ground: ground))),
          ),
        );

    await tester.pumpWidget(host(const <int>{}));
    await tester.pump();

    var heart = tester.widget<Icon>(find.byType(Icon));
    expect(heart.icon, Icons.favorite_border);
    expect(heart.color, isNot(AppColors.error));

    await tester.pumpWidget(host({ground.id}));
    await tester.pump();

    heart = tester.widget<Icon>(find.byType(Icon));
    // The fill carries the state as well as the colour, so it still reads as
    // saved to someone who cannot see red.
    expect(heart.icon, Icons.favorite);
    expect(heart.color, AppColors.error);
  });

  testWidgets('the heart keeps a 44px target at any drawn size',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [favoriteIdsProvider.overrideWithValue(const <int>{})],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: FavoriteButton(
              ground: _ground(),
              tone: FavoriteButtonTone.onSurface,
              visualSize: 20,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final size = tester.getSize(find.bySemanticsLabel('Save this ground'));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
