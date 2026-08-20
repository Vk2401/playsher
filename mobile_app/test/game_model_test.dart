// A game has no schedule or price of its own — it is hosted on a booking, and
// the date, times, venue and money all live there. This pins the model against
// the shape GET /games actually returns.

import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/game_model.dart';

Map<String, dynamic> apiGame({
  String total = '1200.00',
  int seats = 8,
  List<Map<String, dynamic>>? participants,
}) => {
      'id': 5,
      'game_name': 'Sunday 5-a-side',
      'max_participants': seats,
      'game_level': 'intermediate',
      'visibility': 'public',
      'is_active': true,
      'price_per_player': double.parse(total) / seats,
      'total_amount': double.parse(total),
      'hostedByUser': {'id': 3, 'name': 'Bilal'},
      'participants': participants ??
          [
            {'id': 1, 'user_id': 3, 'status': 'accepted'},
            {'id': 2, 'user_id': 4, 'status': 'accepted'},
          ],
      'booking': {
        'id': 42,
        'slot_date': '2026-09-14',
        'slot_time_from': '18:00:00',
        'slot_time_to': '19:00:00',
        'total_amount': total,
        'status': 'confirmed',
        'groundSport': {
          'id': 10,
          'price_per_half_hour': '600.00',
          'ground': {'id': 1, 'name': 'Greenfield Arena', 'address': 'Gulberg III'},
          'sport': {'id': 1, 'name': 'Football'},
        },
      },
    };

void main() {
  test('reads the date and times from the booking', () {
    final g = GameModel.fromJson(apiGame());
    expect(g.gameDate, '2026-09-14');
    expect(g.startTime, '18:00:00');
    expect(g.endTime, '19:00:00');
  });

  test('reads the venue through booking.groundSport', () {
    final g = GameModel.fromJson(apiGame());
    expect(g.groundName, 'Greenfield Arena');
    expect(g.sportName, 'Football');
    expect(g.groundAddress, 'Gulberg III');
  });

  test('reads max_participants, not the never-sent max_players', () {
    expect(GameModel.fromJson(apiGame(seats: 12)).maxPlayers, 12);
  });

  test('shows the server-computed per-player share, not zero', () {
    final g = GameModel.fromJson(apiGame(total: '1200.00', seats: 8));
    expect(g.entryFee, 150.0);
    expect(g.formattedFee, '₹150');
  });

  test('counts only participants holding a seat', () {
    final g = GameModel.fromJson(apiGame(participants: [
      {'id': 1, 'user_id': 3, 'status': 'accepted'},
      {'id': 2, 'user_id': 4, 'status': 'declined'},
      {'id': 3, 'user_id': 5, 'status': 'accepted'},
    ]));
    expect(g.currentPlayers, 2);
    expect(g.spotsLeft, 6);
  });

  test('reads the host from hostedByUser', () {
    expect(GameModel.fromJson(apiGame()).hostName, 'Bilal');
  });

  test('does not claim "Free" when no price came back', () {
    final row = apiGame()..remove('price_per_player');
    (row['booking'] as Map<String, dynamic>).remove('total_amount');
    expect(GameModel.fromJson(row).formattedFee, '—');
  });

  test('derives status from is_active when none is sent', () {
    expect(GameModel.fromJson(apiGame()).status, 'open');
    final closed = apiGame()..['is_active'] = false;
    expect(GameModel.fromJson(closed).status, 'closed');
  });
}
