// Pricing moved from the sport to the venue. Two bugs are pinned here.
//
// First: a card showed ₹0 because startingPrice took the *lowest* per-sport
// price, so one unpriced sport spoke for the whole venue while the detail
// screen quoted the real figure for the selected sport.
//
// Then, fixing that, a fallback to the per-sport prices was left in for cards
// only — so a card said ₹200 while the detail and checkout screens, reading the
// venue price directly, said ₹0. There is now exactly one price, and it is the
// one the server charges from.

import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/ground_model.dart';

GroundModel g(Map<String, dynamic> extra) => GroundModel.fromJson({
      'id': 1,
      'name': 'Green Valley Cricket Ground',
      'images': <dynamic>[],
      'amenities': <dynamic>[],
      'reviews': <dynamic>[],
      ...extra,
    });

void main() {
  group('ground-level price', () {
    test('uses the venue price when it has one', () {
      final ground = g({'price_per_slot': '250.00'});
      expect(ground.pricePerSlot, 250);
      expect(ground.startingPrice, 250);
      expect(ground.formattedStartingPrice, '₹250');
    });

    test('the venue price is the only price, per-sport rows are inert', () {
      final ground = g({
        'price_per_slot': '250.00',
        'groundSports': [
          {'id': 1, 'ground_id': 1, 'price_per_half_hour': '100',
            'sport': {'id': 1, 'name': 'Cricket'}},
        ],
      });
      expect(ground.startingPrice, 250);
    });

    test('no price reads as no price, not as free', () {
      final ground = g({'price_per_slot': '0.00'});
      expect(ground.startingPrice, 0);
      expect(ground.formattedStartingPrice, isNull,
          reason: 'a ₹0 label reads as free; the card should say '
              '"Price on request" instead');
    });
  });

  group('no fallback to the old per-sport prices', () {
    // The app quotes what the server will charge, and the server charges from
    // grounds.price_per_slot alone — refusing with 409 when it is 0. Reading the
    // sport prices here would put a bookable-looking figure on a card that
    // checkout then rejects, and it made a card say ₹200 while the detail screen
    // said ₹0.
    test('per-sport prices are ignored entirely', () {
      final ground = g({
        'price_per_slot': '0.00',
        'groundSports': [
          {'id': 1, 'ground_id': 1, 'price_per_half_hour': '100',
            'sport': {'id': 1, 'name': 'Cricket'}},
          {'id': 2, 'ground_id': 1, 'price_per_half_hour': '200',
            'sport': {'id': 2, 'name': 'Tennis'}},
        ],
      });
      expect(ground.startingPrice, 0);
      expect(ground.formattedStartingPrice, isNull);
      expect(ground.isBookable, isFalse,
          reason: 'the server would refuse this booking, so the app must not '
              'offer it');
    });

    test('a venue with a price is bookable', () {
      final ground = g({'price_per_slot': '250.00'});
      expect(ground.isBookable, isTrue);
    });

    test('a ground with no sports at all does not crash', () {
      expect(g({}).startingPrice, 0);
      expect(g({}).formattedStartingPrice, isNull);
      expect(g({}).isBookable, isFalse);
    });
  });

  group('every sport is listed, not just the first', () {
    test('sportNames returns all of them', () {
      final ground = g({
        'groundSports': [
          {'id': 1, 'ground_id': 1, 'sport': {'id': 1, 'name': 'Cricket'}},
          {'id': 2, 'ground_id': 1, 'sport': {'id': 2, 'name': 'Tennis'}},
          {'id': 3, 'ground_id': 1, 'sport': {'id': 4, 'name': 'Badminton'}},
        ],
      });
      expect(ground.sportNames, ['Cricket', 'Tennis', 'Badminton']);
    });
  });

  group('slots left today', () {
    test('reads the counts the list endpoint sends', () {
      final ground = g({'slots_available_today': 4, 'slots_total_today': 14});
      expect(ground.slotsLeftLabel, '4 of 14 slots left today');
      expect(ground.isFullyBookedToday, isFalse);
    });

    test('zero available is full, not missing', () {
      final ground = g({'slots_available_today': 0, 'slots_total_today': 23});
      expect(ground.isFullyBookedToday, isTrue);
    });

    test('an ungenerated day has no label rather than a wrong one', () {
      expect(g({}).slotsLeftLabel, isNull);
    });
  });
}
