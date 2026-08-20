// The ground-detail hero is a horizontal PageView sitting inside a
// SliverAppBar's FlexibleSpaceBar, underneath a full-bleed gradient overlay.
// This checks a horizontal swipe actually advances it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/ground_model.dart';
import 'package:playsher_app/providers/grounds_provider.dart';
import 'package:playsher_app/screens/ground_detail_screen.dart';

GroundModel groundWithImages() => GroundModel.fromJson({
      'id': 1,
      'name': 'Green Valley Cricket Ground',
      'address': 'Block C, Gulberg III, Lahore',
      'images': [
        {'id': 1, 'image': 'https://example.test/a.jpg', 'is_primary': true},
        {'id': 2, 'image': 'https://example.test/b.jpg', 'is_primary': false},
        {'id': 3, 'image': 'https://example.test/c.jpg', 'is_primary': false},
      ],
      'groundSports': [],
      'amenities': [],
      'reviews': [],
    });

void main() {
  testWidgets('swiping the hero advances the image', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        groundDetailProvider.overrideWith((ref, id) async => groundWithImages()),
        slotsProvider.overrideWith((ref, q) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const GroundDetailScreen(groundId: '1'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final pageView = find.byType(PageView);
    expect(pageView, findsOneWidget, reason: 'hero PageView not found');

    final controller =
        (tester.widget<PageView>(pageView)).controller as PageController;
    expect(controller.page?.round(), 0);

    // Horizontal swipe across the middle of the hero image.
    await tester.drag(pageView, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(controller.page?.round(), 1,
        reason: 'The hero did not advance — the swipe never reached the PageView.');
  });
}
