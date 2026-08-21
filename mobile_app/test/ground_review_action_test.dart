// The review form is earned by playing at a ground, and the API says so through
// /reviews/eligibility. These tests drive the real Reviews tab on the real
// GroundDetailScreen and assert that each eligibility answer produces the right
// affordance — the reported bug being that a qualifying customer saw nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/ground_model.dart';
import 'package:playsher_app/models/review_eligibility_model.dart';
import 'package:playsher_app/providers/grounds_provider.dart';
import 'package:playsher_app/screens/ground_detail_screen.dart';

GroundModel ground() => GroundModel.fromJson({
      'id': 1,
      'name': 'Green Valley Cricket Ground',
      'address': 'Block C, Gulberg III, Lahore',
      'images': <dynamic>[],
      'amenities': <dynamic>[],
      'groundSports': [
        {
          'id': 10,
          'ground_id': 1,
          'price_per_half_hour': '2500',
          'sport': {'id': 1, 'name': 'Cricket'},
        },
      ],
      'reviews': <dynamic>[],
    });

Widget host(ReviewEligibility eligibility) => ProviderScope(
      overrides: [
        groundDetailProvider.overrideWith((ref, id) async => ground()),
        slotsProvider.overrideWith((ref, q) async => const []),
        reviewEligibilityProvider.overrideWith((ref, id) async => eligibility),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const GroundDetailScreen(groundId: '1'),
      ),
    );

/// Renders the screen and opens the Reviews tab, which is where the action
/// lives. The pill sits below the fold on a Pixel-7 viewport, so it has to be
/// scrolled to before it can be tapped.
Future<void> openReviewsTab(
  WidgetTester tester,
  ReviewEligibility eligibility,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(host(eligibility));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  final reviewsPill = find.text('Reviews');
  expect(reviewsPill, findsOneWidget,
      reason: 'the Reviews section pill should exist on the detail screen');

  await tester.dragUntilVisible(
    reviewsPill,
    find.byType(CustomScrollView),
    const Offset(0, -250),
  );
  await tester.pumpAndSettle();

  await tester.tap(reviewsPill);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('a customer who has played there is offered the review form',
      (tester) async {
    const eligibility = ReviewEligibility(canReview: true, bookingId: 5);
    await openReviewsTab(tester, eligibility);

    expect(find.text('Write a review'), findsOneWidget,
        reason: 'can_review: true must surface the form, not hide it');
  });

  testWidgets('someone who never played there is told why, not left guessing',
      (tester) async {
    const eligibility = ReviewEligibility(
      canReview: false,
      reason: 'no_completed_booking',
      message: 'Only players who have booked and played here can leave a review.',
    );
    await openReviewsTab(tester, eligibility);

    expect(find.text('Write a review'), findsNothing);
    expect(
      find.textContaining('booked and played here'),
      findsOneWidget,
      reason: 'the refusal reason should be shown rather than silently hiding',
    );
  });

  testWidgets('an already-reviewed customer is not offered a second form',
      (tester) async {
    const eligibility = ReviewEligibility(
      canReview: false,
      reason: 'already_reviewed',
      message: 'You have already reviewed this ground.',
    );
    await openReviewsTab(tester, eligibility);

    expect(find.text('Write a review'), findsNothing);
    expect(find.textContaining('already reviewed'), findsOneWidget);
  });

  testWidgets('an anonymous browser is shown nothing at all, not a refusal',
      (tester) async {
    const eligibility = ReviewEligibility.unknown;
    await openReviewsTab(tester, eligibility);

    expect(find.text('Write a review'), findsNothing);
    expect(find.textContaining('booked and played here'), findsNothing);
  });
}
