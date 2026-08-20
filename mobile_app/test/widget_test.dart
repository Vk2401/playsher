// Smoke test: the app boots and settles without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:playsher_app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // PlaysherApp reads Riverpod providers, so it needs a ProviderScope above
    // it — without one this threw before the first frame.
    await tester.pumpWidget(const ProviderScope(child: PlaysherApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    // The splash screen schedules its redirect ~2.2s out; let it fire so the
    // test does not end on a pending timer. Discrete pumps rather than
    // pumpAndSettle: the destination shows looping shimmer loaders, which by
    // design never reach a steady state.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
