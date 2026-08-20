// The Flutter model must read the field names the API actually sends.
// It previously read booking_date / total_price, which the API has never
// sent (backend-api/src/models/Booking.js defines slot_date / total_amount),
// so every booking rendered with a blank date and a zero price.

import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/booking_model.dart';

void main() {
  /// A bare row exactly as `GET /bookings` returns it, per the redesign
  /// brief section 5 and the Sequelize model.
  Map<String, dynamic> apiRow({String paymentMethod = 'online'}) => {
        'id': 42,
        'user_id': 7,
        'ground_sport_id': 3,
        'slot_date': '2026-09-14',
        'slot_time_from': '18:00:00',
        'slot_time_to': '19:00:00',
        'total_amount': '1250.00',
        'advance_amount': '125.00',
        'balance_due': '1125.00',
        'is_game': false,
        'is_canceled': false,
        'booking_reference': 'PSH-000042',
        'payment_method': paymentMethod,
        'status': 'confirmed',
      };

  test('reads slot_date, not the never-sent booking_date', () {
    expect(BookingModel.fromJson(apiRow()).bookingDate, '2026-09-14');
  });

  test('reads total_amount, not the never-sent total_price', () {
    final booking = BookingModel.fromJson(apiRow());
    expect(booking.totalPrice, 1250.0);
    expect(booking.formattedPrice, '₹1250');
  });

  test('reads slot_time_from / slot_time_to on a bare list row', () {
    final booking = BookingModel.fromJson(apiRow());
    expect(booking.startTime, '18:00:00');
    expect(booking.endTime, '19:00:00');
  });

  test('reports the real payment method rather than assuming pay-at-ground', () {
    expect(
      BookingModel.fromJson(apiRow(paymentMethod: 'online')).paymentMethodLabel,
      'Paid Online',
    );
    expect(
      BookingModel.fromJson(apiRow(paymentMethod: 'pay_at_ground'))
          .paymentMethodLabel,
      'Pay at Ground',
    );
  });

  test('reads the advance / balance split for the ticket', () {
    final booking = BookingModel.fromJson(apiRow());
    expect(booking.advanceAmount, 125.0);
    expect(booking.balanceDue, 1125.0);
    expect(booking.formattedAdvance, '₹125');
    expect(booking.formattedBalance, '₹1125');
    expect(booking.hasBalanceDue, isTrue);
  });

  test('an online booking owes nothing at the ground', () {
    final row = apiRow(paymentMethod: 'online')
      ..['advance_amount'] = '1250.00'
      ..['balance_due'] = '0.00';
    final booking = BookingModel.fromJson(row);
    expect(booking.hasBalanceDue, isFalse);
    expect(booking.advanceAmount, booking.totalPrice);
  });

  test('a row without the advance columns still parses', () {
    final row = apiRow()
      ..remove('advance_amount')
      ..remove('balance_due');
    final booking = BookingModel.fromJson(row);
    expect(booking.advanceAmount, 0);
    expect(booking.hasBalanceDue, isFalse);
  });

  test('does not claim a payment method the booking does not carry', () {
    final row = apiRow()..remove('payment_method');
    expect(BookingModel.fromJson(row).paymentMethodLabel, 'Not specified');
  });

  test('still reads the nested detail shape from GET /bookings/:id', () {
    final detail = apiRow()
      ..addAll({
        'groundSport': {
          'ground': {
            'name': 'Greenfield Arena',
            'images': [
              {'image': 'https://example.test/g.jpg', 'is_primary': true}
            ],
          },
          'sport': {'name': 'Football'},
        },
      });
    final booking = BookingModel.fromJson(detail);
    expect(booking.groundName, 'Greenfield Arena');
    expect(booking.sportName, 'Football');
    expect(booking.bookingDate, '2026-09-14');
    expect(booking.totalPrice, 1250.0);
  });
}
