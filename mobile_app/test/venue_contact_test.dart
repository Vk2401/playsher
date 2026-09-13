// Directions and a phone number on the way to a game.
//
// `grounds.contact_number` was named in both field whitelists long before the
// column existed, so every write path silently dropped it and the app had no
// way to show a venue's number at all. These cover the three places that can
// now go wrong: the number arriving from the API, what counts as dialable, and
// a bar that must hide the half of itself the venue has no data for.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/core/phone_links.dart';
import 'package:playsher_app/core/theme.dart';
import 'package:playsher_app/models/booking_model.dart';
import 'package:playsher_app/models/ground_model.dart';
import 'package:playsher_app/widgets/venue_contact_bar.dart';

const _devices = <String, Size>{
  'Pixel 7': Size(412, 915),
  'iPhone 14': Size(390, 844),
};
const _scales = <double>[1.0, 1.3];

Widget _host(
  Widget child, {
  required Brightness brightness,
  required double scale,
}) =>
    MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );

Map<String, dynamic> _groundJson({
  Object? contact = '044 4567 8900',
  Object? lat = '13.0827',
  Object? lng = '80.2707',
}) =>
    {
      'id': 3,
      'name': 'Green Valley Turf',
      'contact_number': contact,
      'latitude': lat,
      'longitude': lng,
    };

void main() {
  group('PhoneLinks.sanitize', () {
    test('strips the spacing an owner typed', () {
      expect(PhoneLinks.sanitize('044 4567 8900'), '04445678900');
      expect(PhoneLinks.sanitize('044-4567-8900'), '04445678900');
      expect(PhoneLinks.sanitize('(044) 4567 8900'), '04445678900');
    });

    test('keeps a leading + so an international number still dials', () {
      expect(PhoneLinks.sanitize('+91 98400 12345'), '+919840012345');
    });

    test('a + anywhere but the front is decoration, not a country code', () {
      expect(PhoneLinks.sanitize('9840012345+'), '9840012345');
    });

    test('nothing to dial means null, never an empty dialer', () {
      expect(PhoneLinks.sanitize(null), isNull);
      expect(PhoneLinks.sanitize(''), isNull);
      expect(PhoneLinks.sanitize('   '), isNull);
      expect(PhoneLinks.sanitize('call us'), isNull);
      expect(PhoneLinks.sanitize('-'), isNull);
    });

    test('too few digits is a placeholder, not a number', () {
      expect(PhoneLinks.sanitize('12345'), isNull);
      expect(PhoneLinks.sanitize('123456'), '123456');
    });
  });

  group('PhoneLinks.display', () {
    test('keeps the owner spacing, because it is how the number reads', () {
      expect(PhoneLinks.display('044 4567 8900'), '044 4567 8900');
    });

    test('is null exactly when there is nothing to dial', () {
      expect(PhoneLinks.display('  '), isNull);
      expect(PhoneLinks.display('99'), isNull);
    });
  });

  group('PhoneLinks.dialUri', () {
    test('is a tel: URI carrying the sanitized number', () {
      final uri = PhoneLinks.dialUri('044 4567 8900')!;
      expect(uri.scheme, 'tel');
      expect(uri.path, '04445678900');
      expect(uri.toString(), 'tel:04445678900');
    });

    test('no number, no URI', () {
      expect(PhoneLinks.dialUri(null), isNull);
    });
  });

  group('GroundModel', () {
    test('reads contact_number off the wire', () {
      final g = GroundModel.fromJson(_groundJson());
      expect(g.contactNumber, '044 4567 8900');
      expect(g.callableNumber, '04445678900');
      expect(g.directionsUrl, contains('destination=13.0827%2C80.2707'));
    });

    test('a ground with no number parses, it just has none', () {
      final g = GroundModel.fromJson(_groundJson(contact: null));
      expect(g.contactNumber, isNull);
      expect(g.callableNumber, isNull);
    });

    test('0,0 is unset, so there are no directions to offer', () {
      final g = GroundModel.fromJson(_groundJson(lat: '0', lng: '0'));
      expect(g.directionsUrl, isNull);
    });
  });

  group('BookingModel', () {
    Map<String, dynamic> booking({Object? contact = '044 4567 8900'}) => {
          'id': 8,
          'slot_date': '2026-08-20',
          'status': 'confirmed',
          'total_amount': '200.00',
          'groundSport': {
            'ground': {
              'name': 'Green Valley',
              'latitude': '13.0827',
              'longitude': '80.2707',
              'contact_number': contact,
            },
            'sport': {'name': 'Cricket'},
          },
        };

    test('carries the venue number onto the ticket', () {
      final b = BookingModel.fromJson(booking());
      expect(b.groundContactNumber, '044 4567 8900');
      expect(b.venueContact.hasPhone, isTrue);
      expect(b.venueContact.hasDirections, isTrue);
    });

    test('a venue that set no number still offers directions', () {
      final b = BookingModel.fromJson(booking(contact: null));
      expect(b.venueContact.hasPhone, isFalse);
      expect(b.venueContact.hasDirections, isTrue);
      expect(b.venueContact.isEmpty, isFalse);
    });
  });

  group('VenueContact', () {
    test('knows which halves the venue actually has', () {
      final both = GroundModel.fromJson(_groundJson()).venueContact;
      expect(both.hasDirections, isTrue);
      expect(both.hasPhone, isTrue);
      expect(both.isEmpty, isFalse);

      final noPhone =
          GroundModel.fromJson(_groundJson(contact: '')).venueContact;
      expect(noPhone.hasPhone, isFalse);
      expect(noPhone.isEmpty, isFalse);

      final neither =
          GroundModel.fromJson(_groundJson(contact: null, lat: null, lng: null))
              .venueContact;
      expect(neither.isEmpty, isTrue);
    });

    test('compares by value, so it survives being passed through extra', () {
      const a = VenueContact(phone: '9840012345', latitude: 13, longitude: 80);
      const b = VenueContact(phone: '9840012345', latitude: 13, longitude: 80);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('VenueContactBar', () {
    Future<void> everyCombination(
      WidgetTester tester,
      Widget Function() build,
    ) async {
      for (final device in _devices.entries) {
        for (final brightness in Brightness.values) {
          for (final scale in _scales) {
            tester.view.physicalSize = device.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              _host(build(), brightness: brightness, scale: scale),
            );
            await tester.pumpAndSettle();

            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${device.key} · ${brightness.name} · ${scale}x text scale',
            );
          }
        }
      }
    }

    testWidgets('shows both actions and the number itself', (tester) async {
      await tester.pumpWidget(_host(
        const VenueContactBar(
          contact: VenueContact(
            phone: '044 4567 8900',
            latitude: 13.0827,
            longitude: 80.2707,
          ),
        ),
        brightness: Brightness.light,
        scale: 1.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Call venue'), findsOneWidget);
      // The digits, not just a button that promises them.
      expect(find.text('044 4567 8900'), findsOneWidget);
    });

    testWidgets('hides the half the venue has no data for', (tester) async {
      await tester.pumpWidget(_host(
        const VenueContactBar(
          contact: VenueContact(latitude: 13.0827, longitude: 80.2707),
        ),
        brightness: Brightness.light,
        scale: 1.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('Call venue'), findsNothing);

      await tester.pumpWidget(_host(
        const VenueContactBar(contact: VenueContact(phone: '9840012345')),
        brightness: Brightness.light,
        scale: 1.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Directions'), findsNothing);
      expect(find.text('Call venue'), findsOneWidget);
    });

    testWidgets('renders nothing at all when the venue has neither',
        (tester) async {
      await tester.pumpWidget(_host(
        const VenueContactBar(contact: VenueContact()),
        brightness: Brightness.light,
        scale: 1.0,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('every tap target clears 44px', (tester) async {
      tester.view.physicalSize = _devices['iPhone 14']!;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(
        const VenueContactBar(
          contact: VenueContact(
            phone: '044 4567 8900',
            latitude: 13.0827,
            longitude: 80.2707,
          ),
        ),
        brightness: Brightness.light,
        scale: 1.0,
      ));
      await tester.pumpAndSettle();

      for (final element in find.byType(OutlinedButton).evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('lays out on both devices, themes and at 1.3x text',
        (tester) async {
      await everyCombination(
        tester,
        () => const VenueContactBar(
          contact: VenueContact(
            phone: '+91 98400 12345',
            latitude: 13.0827,
            longitude: 80.2707,
          ),
        ),
      );
    });

    testWidgets('showNumber: false keeps the buttons and drops the digits',
        (tester) async {
      await tester.pumpWidget(_host(
        const VenueContactBar(
          contact: VenueContact(phone: '044 4567 8900'),
          showNumber: false,
        ),
        brightness: Brightness.light,
        scale: 1.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Call venue'), findsOneWidget);
      expect(find.text('044 4567 8900'), findsNothing);
    });
  });
}
