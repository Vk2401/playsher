// The checkout quoted ₹0 while the server charged the real amount, because
// this model read `price_per_slot` — a key the API has never sent. Its field
// is price_per_half_hour.

import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/ground_sport_model.dart';

Map<String, dynamic> apiRow() => {
      'id': 10,
      'ground_id': 1,
      'price_per_half_hour': '100.00',
      'min_slots': 2,
      'max_slots': 6,
      'sport': {'id': 1, 'name': 'Cricket'},
    };

void main() {
  test('reads price_per_half_hour, not the never-sent price_per_slot', () {
    final gs = GroundSportModel.fromJson(apiRow());
    expect(gs.pricePerSlot, 100.0);
    expect(gs.formattedPrice, '₹ 100');
  });

  test('a booking total is the slot price times the slot count', () {
    final gs = GroundSportModel.fromJson(apiRow());
    // One slot on the reported booking came to ₹100 server-side; the checkout
    // must agree rather than showing zero.
    expect(gs.pricePerSlot * 1, 100.0);
    expect(gs.pricePerSlot * 3, 300.0);
  });

  test('carries the server-enforced slot limits', () {
    final gs = GroundSportModel.fromJson(apiRow());
    expect(gs.minSlots, 2);
    expect(gs.maxSlots, 6);
  });

  test('defaults sensibly when limits are absent', () {
    final row = apiRow()
      ..remove('min_slots')
      ..remove('max_slots');
    final gs = GroundSportModel.fromJson(row);
    expect(gs.minSlots, 1);
    expect(gs.maxSlots, 8);
  });

  test('a missing price is zero rather than a crash', () {
    final row = apiRow()..remove('price_per_half_hour');
    expect(GroundSportModel.fromJson(row).pricePerSlot, 0);
  });
}
