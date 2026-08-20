import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/booking_share.dart';
import 'package:playsher_app/core/map_links.dart';
import 'package:playsher_app/models/booking_model.dart';
import 'package:playsher_app/models/review_eligibility_model.dart';

void main() {
  group('MapLinks', () {
    test('builds a universal maps directions URL', () {
      final url = MapLinks.directionsUrl(latitude: 13.0827, longitude: 80.2707);
      expect(url, contains('google.com/maps/dir/'));
      expect(url, contains('api=1'));
      expect(url, contains('destination=13.0827%2C80.2707'));
    });

    test('is an https link, so it survives being pasted into a chat', () {
      final url = MapLinks.directionsUrl(latitude: 13.08, longitude: 80.27)!;
      expect(url, startsWith('https://'));
    });

    test('no coordinates means no link, not a broken one', () {
      expect(MapLinks.directionsUrl(latitude: null, longitude: 80.27), isNull);
      expect(MapLinks.directionsUrl(latitude: 13.08, longitude: null), isNull);
      expect(MapLinks.directionsUrl(), isNull);
    });

    test('0,0 is treated as unset rather than the null island', () {
      expect(MapLinks.directionsUrl(latitude: 0, longitude: 0), isNull);
      expect(MapLinks.directionsUrl(latitude: 0, longitude: 80.27), isNull);
    });

    test('negative coordinates work', () {
      final url = MapLinks.directionsUrl(latitude: -33.86, longitude: 151.2);
      expect(url, contains('destination=-33.86%2C151.2'));
    });
  });

  group('BookingModel directions', () {
    Map<String, dynamic> payload({dynamic lat = '13.0827', dynamic lng = '80.2707'}) => {
          'id': 8,
          'slot_date': '2026-08-20',
          'status': 'confirmed',
          'total_amount': '200.00',
          'groundSport': {
            'ground': {
              'name': 'Green Valley',
              'address': '5 MG Road',
              'latitude': lat,
              'longitude': lng,
            },
            'sport': {'name': 'Cricket'},
          },
        };

    test('parses coordinates that arrive as strings', () {
      final b = BookingModel.fromJson(payload());
      expect(b.groundLatitude, 13.0827);
      expect(b.groundLongitude, 80.2707);
      expect(b.hasDirections, isTrue);
    });

    test('parses the address', () {
      expect(BookingModel.fromJson(payload()).groundAddress, '5 MG Road');
    });

    test('a ground with no coordinates offers no directions', () {
      final b = BookingModel.fromJson(payload(lat: null, lng: null));
      expect(b.hasDirections, isFalse);
      expect(b.directionsUrl, isNull);
    });
  });

  group('Share text carries directions', () {
    test('includes the maps link when there is one', () {
      final text = BookingShare.build(
        groundName: 'Green Valley',
        directionsUrl: 'https://www.google.com/maps/dir/?api=1&destination=13,80',
      );
      expect(text, contains('Directions: https://www.google.com/maps/dir/'));
    });

    test('omits the line when the ground has no coordinates', () {
      final text = BookingShare.build(groundName: 'Green Valley');
      expect(text, isNot(contains('Directions:')));
    });
  });

  group('ReviewEligibility', () {
    test('reads a positive answer', () {
      final e = ReviewEligibility.fromJson(
          {'can_review': true, 'booking_id': 42});
      expect(e.canReview, isTrue);
      expect(e.bookingId, 42);
    });

    test('reads the no-booking refusal with its reason', () {
      final e = ReviewEligibility.fromJson({
        'can_review': false,
        'reason': 'no_completed_booking',
        'message': 'Only players who have booked and played here can leave a review.',
      });
      expect(e.canReview, isFalse);
      expect(e.needsBooking, isTrue);
      expect(e.alreadyReviewed, isFalse);
      expect(e.message, contains('booked and played'));
    });

    test('reads the already-reviewed refusal', () {
      final e = ReviewEligibility.fromJson(
          {'can_review': false, 'reason': 'already_reviewed'});
      expect(e.alreadyReviewed, isTrue);
      expect(e.needsBooking, isFalse);
    });

    test('an empty payload offers no form and states no reason', () {
      final e = ReviewEligibility.fromJson({});
      expect(e.canReview, isFalse);
      expect(e.reason, isNull);
    });

    test('unknown never offers the form', () {
      expect(ReviewEligibility.unknown.canReview, isFalse);
      expect(ReviewEligibility.unknown.reason, isNull);
    });
  });
}
