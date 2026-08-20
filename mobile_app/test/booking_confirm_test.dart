import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/booking_share.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/screens/booking_confirm_screen.dart';

/// What the booking flow actually puts in `extra`: the created Booking row
/// plus the two display fields the row does not carry.
Map<String, dynamic> payload({
  String paymentMethod = 'Online',
  String total = '100.00',
  String advance = '100.00',
  String balance = '0.00',
  String? from = '18:30:00',
  String? to = '19:00:00',
  String? ground = 'Green Valley Cricket Ground',
}) =>
    {
      'id': 9,
      'booking_reference': '20260820-1830-1900-9',
      'slot_date': '2026-08-20',
      'slot_time_from': from,
      'slot_time_to': to,
      'total_amount': total,
      'advance_amount': advance,
      'balance_due': balance,
      'payment_method': paymentMethod,
      'ground_name': ground,
      'sport_name': 'Cricket',
    };

Widget host(Map<String, dynamic> data) => MaterialApp(
      theme: AppTheme.dark,
      home: BookingConfirmScreen(bookingData: data),
    );

void main() {
  group('Confirmation screen shows the whole booking', () {
    testWidgets('formats the date instead of printing the raw value',
        (tester) async {
      await tester.pumpWidget(host(payload()));
      await tester.pumpAndSettle();
      expect(find.text('Thu, 20 Aug 2026'), findsOneWidget);
      expect(find.text('2026-08-20'), findsNothing);
    });

    testWidgets('shows the time, which was missing entirely', (tester) async {
      await tester.pumpWidget(host(payload()));
      await tester.pumpAndSettle();
      expect(find.textContaining('6:30 PM - 7:00 PM'), findsOneWidget);
    });

    testWidgets('shows the duration alongside the time', (tester) async {
      await tester.pumpWidget(host(payload()));
      await tester.pumpAndSettle();
      expect(find.textContaining('30 min'), findsOneWidget);
    });

    testWidgets('shows ground, sport and reference', (tester) async {
      await tester.pumpWidget(host(payload()));
      await tester.pumpAndSettle();
      expect(find.text('Green Valley Cricket Ground'), findsOneWidget);
      expect(find.text('Cricket'), findsWidgets);
      expect(find.text('20260820-1830-1900-9'), findsOneWidget);
    });

    testWidgets('an online booking reads as paid', (tester) async {
      await tester.pumpWidget(host(payload()));
      await tester.pumpAndSettle();
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('Paid online'), findsOneWidget);
      expect(find.text('Due at the ground'), findsNothing);
    });

    testWidgets('pay-at-ground leads with what is still owed', (tester) async {
      await tester.pumpWidget(host(payload(
        paymentMethod: 'Pay at Ground',
        total: '200.00',
        advance: '20.00',
        balance: '180.00',
      )));
      await tester.pumpAndSettle();
      expect(find.text('Booking Confirmed!'), findsOneWidget);
      expect(find.textContaining('Pay ₹180 at the ground'), findsOneWidget);
      expect(find.text('Advance paid'), findsOneWidget);
      expect(find.text('Due at the ground'), findsOneWidget);
    });

    testWidgets('accepts the API wire value for the method too', (tester) async {
      // The flow sends 'Online'; the raw row carries 'online'.
      await tester.pumpWidget(host(payload(paymentMethod: 'online')));
      await tester.pumpAndSettle();
      expect(find.text('Payment Successful!'), findsOneWidget);
    });

    testWidgets('offers a share action', (tester) async {
      await tester.pumpWidget(host(payload()));
      await tester.pumpAndSettle();
      expect(find.text('Share booking details'), findsOneWidget);
    });

    testWidgets('keeps both navigation actions', (tester) async {
      await tester.pumpWidget(host(payload()));
      await tester.pumpAndSettle();
      expect(find.text('View My Bookings'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('Confirmation screen degrades safely', () {
    testWidgets('no times means no time row, not a crash', (tester) async {
      await tester.pumpWidget(host(payload(from: null, to: null)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Time'), findsNothing);
      expect(find.text('Thu, 20 Aug 2026'), findsOneWidget);
    });

    testWidgets('an empty payload still renders', (tester) async {
      await tester.pumpWidget(host({}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Your booking'), findsOneWidget);
    });

    testWidgets('a very long ground name does not overflow', (tester) async {
      await tester.pumpWidget(host(payload(
        ground: 'The Extremely Long Memorial Sports Complex and Cricket Academy',
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: BookingConfirmScreen(bookingData: payload()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Payment Successful!'), findsOneWidget);
    });

    testWidgets('fits a short screen without overflowing', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host(payload(
        paymentMethod: 'Pay at Ground',
        total: '200.00',
        advance: '20.00',
        balance: '180.00',
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('BookingShare text', () {
    test('leads with the sport and the venue', () {
      final text = BookingShare.build(
        sportName: 'Cricket',
        groundName: 'Green Valley Cricket Ground',
      );
      expect(text.split('\n').first,
          'Cricket at Green Valley Cricket Ground — booked!');
    });

    test('carries the facts a recipient needs to show up', () {
      final text = BookingShare.build(
        reference: '20260820-1830-1900-9',
        groundName: 'Green Valley Cricket Ground',
        sportName: 'Cricket',
        date: 'Thu, 20 Aug 2026',
        timeRange: '6:30 PM - 7:00 PM',
        duration: '30 min',
        total: '₹100',
        amountPaid: '₹100',
        paymentMethod: 'Paid online',
      );
      expect(text, contains('Date: Thu, 20 Aug 2026'));
      expect(text, contains('Time: 6:30 PM - 7:00 PM'));
      expect(text, contains('Venue: Green Valley Cricket Ground'));
      expect(text, contains('Booking ref: 20260820-1830-1900-9'));
      expect(text, contains('Total: ₹100'));
      expect(text, contains('Booked with Playsher'));
    });

    test('omits fields it does not have rather than printing dashes', () {
      final text = BookingShare.build(
        groundName: 'Green Valley Cricket Ground',
        date: 'Thu, 20 Aug 2026',
      );
      expect(text, isNot(contains('Time:')));
      expect(text, isNot(contains('Booking ref:')));
      expect(text, isNot(contains('—\n')));
    });

    test('treats an em-dash placeholder as missing', () {
      final text = BookingShare.build(groundName: '—', date: 'Thu, 20 Aug 2026');
      expect(text, isNot(contains('Venue:')));
    });

    test('surfaces a balance still owed at the venue', () {
      final text = BookingShare.build(
        groundName: 'Green Valley',
        total: '₹200',
        amountPaid: '₹20',
        balanceDue: '₹180',
      );
      expect(text, contains('Due at venue: ₹180'));
    });

    test('an entirely empty booking still produces sane text', () {
      final text = BookingShare.build();
      expect(text, startsWith('Playsher booking'));
      expect(text, contains('Booked with Playsher'));
    });
  });
}
