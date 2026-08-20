import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/booking_model.dart';

/// A payload shaped like what the API now returns for a booking.
Map<String, dynamic> payload({
  List<Map<String, dynamic>>? slots,
  String? sport = 'Cricket',
  String? reference = '20260820-1800-1930-8',
}) =>
    {
      'id': 8,
      'slot_date': '2026-08-20',
      'status': 'confirmed',
      'total_amount': '200.00',
      'advance_amount': '20.00',
      'balance_due': '180.00',
      'payment_method': 'pay_at_ground',
      'booking_reference': reference,
      'created_at': '2026-08-19T11:55:00.000Z',
      'groundSport': {
        'ground': {'name': 'Green Valley Cricket Ground'},
        if (sport != null) 'sport': {'name': sport},
      },
      'slots': slots ?? [
        {'slot_start_time': '18:00:00', 'slot_end_time': '18:30:00'},
        {'slot_start_time': '18:30:00', 'slot_end_time': '19:00:00'},
        {'slot_start_time': '19:00:00', 'slot_end_time': '19:30:00'},
      ],
      'paymentRecord': {'status': 'pending'},
    };

void main() {
  group('BookingModel parses what the API sends', () {
    test('reads the sport off groundSport', () {
      expect(BookingModel.fromJson(payload()).sportName, 'Cricket');
    });

    test('reads the ground name', () {
      expect(BookingModel.fromJson(payload()).groundName,
          'Green Valley Cricket Ground');
    });

    test('reads payment status from the paymentRecord alias', () {
      expect(BookingModel.fromJson(payload()).paymentStatus, 'pending');
    });

    test('counts every booked slot, not just one', () {
      expect(BookingModel.fromJson(payload()).slotCount, 3);
    });

    test('spans earliest start to latest end across slots', () {
      final b = BookingModel.fromJson(payload());
      expect(b.startTime, '18:00:00');
      expect(b.endTime, '19:30:00');
    });

    test('spans correctly even when slots arrive out of order', () {
      final b = BookingModel.fromJson(payload(slots: [
        {'slot_start_time': '19:00:00', 'slot_end_time': '19:30:00'},
        {'slot_start_time': '18:00:00', 'slot_end_time': '18:30:00'},
        {'slot_start_time': '18:30:00', 'slot_end_time': '19:00:00'},
      ]));
      expect(b.startTime, '18:00:00');
      expect(b.endTime, '19:30:00');
    });
  });

  group('Display helpers', () {
    test('formats the date readably', () {
      expect(BookingModel.fromJson(payload()).formattedDate, '20 Aug 2026');
    });

    test('includes the weekday in the long form', () {
      // 2026-08-20 is a Thursday.
      expect(BookingModel.fromJson(payload()).formattedDateLong,
          'Thu, 20 Aug 2026');
    });

    test('renders a 12-hour time range', () {
      expect(BookingModel.fromJson(payload()).timeRange, '6:00 PM - 7:30 PM');
    });

    test('handles noon and midnight without a 0 o\'clock', () {
      final noon = BookingModel.fromJson(payload(slots: [
        {'slot_start_time': '12:00:00', 'slot_end_time': '12:30:00'},
      ]));
      expect(noon.timeRange, '12:00 PM - 12:30 PM');

      final midnight = BookingModel.fromJson(payload(slots: [
        {'slot_start_time': '00:00:00', 'slot_end_time': '00:30:00'},
      ]));
      expect(midnight.timeRange, '12:00 AM - 12:30 AM');
    });

    test('computes the duration across slots', () {
      expect(BookingModel.fromJson(payload()).durationLabel, '1 hr 30 min');
    });

    test('a single slot reads as minutes', () {
      final b = BookingModel.fromJson(payload(slots: [
        {'slot_start_time': '18:00:00', 'slot_end_time': '18:30:00'},
      ]));
      expect(b.durationLabel, '30 min');
      expect(b.slotCountLabel, '1 slot');
    });

    test('pluralises the slot count', () {
      expect(BookingModel.fromJson(payload()).slotCountLabel, '3 slots');
    });

    test('prefers the server booking reference over the row id', () {
      expect(BookingModel.fromJson(payload()).referenceLabel,
          '20260820-1800-1930-8');
    });

    test('falls back to the row id when there is no reference', () {
      expect(BookingModel.fromJson(payload(reference: null)).referenceLabel,
          '#8');
    });

    test('advance and balance are read for pay-at-ground', () {
      final b = BookingModel.fromJson(payload());
      expect(b.formattedPrice, '₹200');
      expect(b.formattedAdvance, '₹20');
      expect(b.formattedBalance, '₹180');
      expect(b.hasBalanceDue, isTrue);
    });
  });

  group('Missing data degrades safely', () {
    test('no slots means no time, not a crash', () {
      final b = BookingModel.fromJson(payload(slots: []));
      expect(b.timeRange, isNull);
      expect(b.durationLabel, isNull);
      expect(b.slotCountLabel, isNull);
      expect(b.slotCount, 0);
    });

    test('a missing sport is null rather than a bad guess', () {
      expect(BookingModel.fromJson(payload(sport: null)).sportName, isNull);
    });

    test('an unparseable date is shown raw rather than blanked', () {
      final b = BookingModel.fromJson({...payload(), 'slot_date': 'someday'});
      expect(b.formattedDate, 'someday');
    });
  });
}
