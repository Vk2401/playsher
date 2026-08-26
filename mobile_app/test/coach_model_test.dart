// The coach models must read the field names `GET /coaches` and
// `GET /coach-bookings` actually send. The old CoachModel read bio /
// experience / hourly_rate / photo, none of which the API has ever sent —
// backend-api/src/models/Coach.js defines about / experience_years /
// price_per_slot / profile_picture — so every coach rendered with no bio,
// zero experience and a ₹0 rate that reads as free.

import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/coach_booking_model.dart';
import 'package:playsher_app/models/coach_model.dart';

void main() {
  /// A coach exactly as `GET /coaches/:id` returns it.
  Map<String, dynamic> apiCoach({String pricePerSlot = '300.00'}) => {
        'id': 9,
        'name': 'Ravi Kumar',
        'sport_id': 2,
        'sport_name': 'Cricket',
        'sport': {'id': 2, 'name': 'Cricket'},
        'experience_years': 7,
        'level': 'professional',
        'city': 'Bengaluru',
        'price_per_slot': pricePerSlot,
        'about': 'Batting coach, ten seasons of league cricket.',
        'experience_details': 'State under-19 squad.',
        'awards': 'Best coach 2024',
        'qualities': 'Batting, Fielding, Fitness',
        'profile_picture': 'https://cdn.example.com/ravi.jpg',
        'rating': '4.5',
        'review_count': 12,
        'groundLinks': [
          {
            'id': 4,
            'ground_id': 3,
            'status': 'approved',
            'ground': {
              'id': 3,
              'name': 'Turf Park',
              'area': 'Indiranagar',
              'city': 'Bengaluru',
              'images': [
                {'id': 1, 'image': 'a.jpg', 'is_primary': false},
                {'id': 2, 'image': 'b.jpg', 'is_primary': true},
              ],
            },
          },
        ],
      };

  group('CoachModel', () {
    test('reads about / experience_years / profile_picture', () {
      final coach = CoachModel.fromJson(apiCoach());
      expect(coach.about, 'Batting coach, ten seasons of league cricket.');
      expect(coach.experienceYears, 7);
      expect(coach.experienceLabel, '7 years');
      expect(coach.photo, 'https://cdn.example.com/ravi.jpg');
    });

    test('prices per 30-minute slot, and quotes the hourly figure from it', () {
      final coach = CoachModel.fromJson(apiCoach());
      expect(coach.pricePerSlot, 300.0);
      expect(coach.isBookable, isTrue);
      expect(coach.formattedRate, '₹300');
      expect(coach.rateCaption, 'per 30 min');
      expect(coach.formattedHourlyRate, '₹600/hr');
    });

    test('an unpriced coach reads as "Price on request", never as ₹0', () {
      final coach = CoachModel.fromJson(apiCoach(pricePerSlot: '0.00'));
      expect(coach.isBookable, isFalse);
      expect(coach.formattedRate, 'Price on request');
      // ₹0 would read as free; the create endpoint answers 409 for this coach.
      expect(coach.formattedRate, isNot(contains('0')));
    });

    test('lifts the approved grounds out of groundLinks', () {
      final coach = CoachModel.fromJson(apiCoach());
      expect(coach.venues, hasLength(1));
      expect(coach.venues.single.name, 'Turf Park');
      expect(coach.venues.single.locality, 'Indiranagar, Bengaluru');
      expect(coach.venues.single.image, 'b.jpg'); // the primary one
      expect(coach.locality, 'Indiranagar, Bengaluru');
    });

    test('splits qualities into chips and drops the blanks', () {
      final row = apiCoach()..['qualities'] = 'Batting, , Fielding\nFitness ';
      final coach = CoachModel.fromJson(row);
      expect(coach.expertiseTags, ['Batting', 'Fielding', 'Fitness']);
    });

    test('survives a row with nothing but an id and a name', () {
      final coach = CoachModel.fromJson({'id': 1, 'name': 'Solo'});
      expect(coach.pricePerSlot, 0);
      expect(coach.venues, isEmpty);
      expect(coach.expertiseTags, isEmpty);
      expect(coach.rating, 0);
    });
  });

  /// A session exactly as `GET /coach-bookings` returns it.
  Map<String, dynamic> apiSession({String status = 'pending'}) => {
        'id': 55,
        'coach_id': 9,
        'ground_id': 3,
        'session_date': '2026-09-14',
        'time_from': '07:00:00',
        'time_to': '08:00:00',
        'total_amount': '600.00',
        'status': status,
        'payment_method': 'pay_at_venue',
        'booking_reference': 'CS-20260914-0700-55',
        'customer_note': 'Working on my cover drive.',
        'coach': {
          'id': 9,
          'name': 'Ravi Kumar',
          'sport_name': 'Cricket',
          'profile_picture': 'https://cdn.example.com/ravi.jpg',
          'mobile': '+919876543210',
        },
        'ground': {
          'id': 3,
          'name': 'Turf Park',
          'area': 'Indiranagar',
          'city': 'Bengaluru',
        },
      };

  group('CoachBookingModel', () {
    test('reads the session fields and its coach', () {
      final session = CoachBookingModel.fromJson(apiSession());
      expect(session.coachName, 'Ravi Kumar');
      expect(session.groundName, 'Turf Park');
      expect(session.groundLocality, 'Indiranagar, Bengaluru');
      expect(session.totalAmount, 600.0);
      expect(session.formattedAmount, '₹600');
      expect(session.timeRange, '7:00 AM - 8:00 AM');
    });

    test('says "Awaiting coach" rather than implying a pending session is set',
        () {
      expect(CoachBookingModel.fromJson(apiSession()).statusLabel,
          'Awaiting coach');
      expect(
          CoachBookingModel.fromJson(apiSession(status: 'confirmed'))
              .statusLabel,
          'Confirmed');
      expect(
          CoachBookingModel.fromJson(apiSession(status: 'rejected'))
              .statusLabel,
          'Declined');
    });

    test('only a pending or confirmed session can still be cancelled', () {
      expect(CoachBookingModel.fromJson(apiSession()).isCancellable, isTrue);
      expect(
          CoachBookingModel.fromJson(apiSession(status: 'confirmed'))
              .isCancellable,
          isTrue);
      for (final done in ['completed', 'cancelled', 'rejected']) {
        expect(CoachBookingModel.fromJson(apiSession(status: done)).isCancellable,
            isFalse,
            reason: '$done is over');
      }
    });

    test('reads session_date as a calendar day, zone suffix and all', () {
      final row = apiSession()..['session_date'] = '2026-09-14T00:00:00.000Z';
      final session = CoachBookingModel.fromJson(row);
      expect(session.sessionDate, '2026-09-14');
      expect(session.formattedDate, 'Mon, 14 Sep 2026');
    });
  });
}
