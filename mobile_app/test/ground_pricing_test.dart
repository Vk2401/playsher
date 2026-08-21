// Pricing moved from the sport to the venue. The bug this pins: a card showed
// ₹0 because startingPrice took the *lowest* per-sport price, and one unpriced
// sport was enough to win — while the detail screen showed the real price for
// the sport actually selected.

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

    test('the venue price wins over any per-sport leftovers', () {
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

  group('legacy fallback, for an API that has not been updated', () {
    test('takes the highest per-sport price, not the lowest', () {
      // The reported bug exactly: Badminton at 0 dragged the card to ₹0 even
      // though Cricket was 100 and Tennis 200.
      final ground = g({
        'groundSports': [
          {'id': 1, 'ground_id': 1, 'price_per_half_hour': '0',
            'sport': {'id': 4, 'name': 'Badminton'}},
          {'id': 2, 'ground_id': 1, 'price_per_half_hour': '100',
            'sport': {'id': 1, 'name': 'Cricket'}},
          {'id': 3, 'ground_id': 1, 'price_per_half_hour': '200',
            'sport': {'id': 2, 'name': 'Tennis'}},
        ],
      });
      expect(ground.startingPrice, 200);
      expect(ground.formattedStartingPrice, '₹200');
    });

    test('all sports unpriced still reads as no price', () {
      final ground = g({
        'groundSports': [
          {'id': 1, 'ground_id': 1, 'price_per_half_hour': '0',
            'sport': {'id': 1, 'name': 'Football'}},
          {'id': 2, 'ground_id': 1, 'price_per_half_hour': '0',
            'sport': {'id': 2, 'name': 'Basketball'}},
        ],
      });
      expect(ground.formattedStartingPrice, isNull);
    });

    test('a ground with no sports at all does not crash', () {
      expect(g({}).startingPrice, 0);
      expect(g({}).formattedStartingPrice, isNull);
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
