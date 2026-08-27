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

  test('a zero share is unpriced, not free', () {
    // The API sends 0 for a game whose booking carries no total, and a ground
    // priced at 0 cannot be booked at all — so "₹0"/"Free" would be a claim
    // nobody made. §7 of CLAUDE.md: "Price on request".
    final row = apiGame()
      ..['price_per_player'] = 0
      ..['total_amount'] = 0;
    (row['booking'] as Map<String, dynamic>)['total_amount'] = '0.00';

    final g = GameModel.fromJson(row);
    expect(g.entryFee, isNull);
    expect(g.totalAmount, isNull);
    expect(g.formattedFee, '—');
  });

  test('derives status from is_active when none is sent', () {
    expect(GameModel.fromJson(apiGame()).status, 'open');
    // The API's own vocabulary — an inactive game is one the host called off.
    final closed = apiGame()..['is_active'] = false;
    expect(GameModel.fromJson(closed).status, 'cancelled');
  });

  // ── The server is the authority on state and seats ──────────────────────────

  test('takes the status the server derived, never recomputing it', () {
    // A game whose seats all look free but which the server says is over must
    // read as over: the card and the endpoint that refuses the join have to
    // agree.
    final played = apiGame(participants: [])..['status'] = 'completed';
    final g = GameModel.fromJson(played);
    expect(g.status, 'completed');
    expect(g.isOpen, isFalse);
    expect(g.canJoin, isFalse);
    expect(g.statusLabel, 'Played');
  });

  test('prefers the server seat count over counting participants', () {
    // GET /games sends `joined_count`; the participant array on a list row may
    // be trimmed. The count is the one the fill bar must show.
    final row = apiGame(seats: 10, participants: [
      {'id': 1, 'user_id': 3, 'status': 'accepted'},
    ])
      ..['joined_count'] = 7;
    final g = GameModel.fromJson(row);
    expect(g.currentPlayers, 7);
    expect(g.spotsLeft, 3);
  });

  test('reads the viewer flags the API attaches', () {
    final row = apiGame()
      ..['is_host'] = true
      ..['is_joined'] = true;
    final g = GameModel.fromJson(row);
    expect(g.isHost, isTrue);
    expect(g.isJoined, isTrue);
    // Hosting already holds a seat — there is nothing left to join.
    expect(g.canJoin, isFalse);
  });

  test('a full game cannot be joined even when the status says open', () {
    final g = GameModel.fromJson(apiGame(seats: 2, participants: [
      {'id': 1, 'user_id': 3, 'status': 'joined'},
      {'id': 2, 'user_id': 4, 'status': 'joined'},
    ]));
    expect(g.isFull, isTrue);
    expect(g.spotsLeft, 0);
    expect(g.spotsLabel, 'Full');
  });

  test('spotsLeft never goes negative when the host shrank the game', () {
    final g = GameModel.fromJson(apiGame(seats: 2)..['joined_count'] = 5);
    expect(g.spotsLeft, 0);
    expect(g.isFull, isTrue);
  });

  // ── The flattened payload ───────────────────────────────────────────────────

  test('reads the flattened keys the API now sends', () {
    final row = apiGame()
      ..['ground_name'] = 'Flat Arena'
      ..['ground_area'] = 'Adyar'
      ..['ground_city'] = 'Chennai'
      ..['sport_name'] = 'Cricket'
      ..['slot_date'] = '2026-09-20';
    final g = GameModel.fromJson(row);
    expect(g.groundName, 'Flat Arena');
    expect(g.sportName, 'Cricket');
    expect(g.gameDate, '2026-09-20');
    expect(g.locationLabel, 'Adyar, Chennai');
  });

  test('falls back to the nested booking when the flat keys are absent', () {
    final g = GameModel.fromJson(apiGame());
    expect(g.groundName, 'Greenfield Arena');
    expect(g.sportName, 'Football');
  });

  // ── Labels ──────────────────────────────────────────────────────────────────

  test('formats the slot times as a readable range', () {
    expect(GameModel.fromJson(apiGame()).timeLabel, '6:00 PM – 7:00 PM');
  });

  test('names today and tomorrow rather than printing a date', () {
    String two(int v) => v.toString().padLeft(2, '0');
    String iso(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
    final now = DateTime.now();

    final today = apiGame();
    (today['booking'] as Map<String, dynamic>)['slot_date'] = iso(now);
    expect(GameModel.fromJson(today).dayLabel, 'Today');

    final tomorrow = apiGame();
    (tomorrow['booking'] as Map<String, dynamic>)['slot_date'] =
        iso(now.add(const Duration(days: 1)));
    expect(GameModel.fromJson(tomorrow).dayLabel, 'Tomorrow');
  });

  test('titles a nameless game after its sport and venue', () {
    final row = apiGame()..remove('game_name');
    expect(GameModel.fromJson(row).displayTitle,
        'Football at Greenfield Arena');
  });

  test('shows the level with the label the host picked it by', () {
    expect(GameModel.fromJson(apiGame()).levelLabel, 'Intermediate');
    final ultra = apiGame()..['game_level'] = 'ultra_professional';
    expect(GameModel.fromJson(ultra).levelLabel, 'Ultra pro');
  });

  test('flags a game down to its last seats as filling fast', () {
    final tight = GameModel.fromJson(apiGame(seats: 8)..['joined_count'] = 7);
    expect(tight.isFillingFast, isTrue);
    expect(tight.spotsLabel, 'Last spot');

    final roomy = GameModel.fromJson(apiGame(seats: 8)..['joined_count'] = 2);
    expect(roomy.isFillingFast, isFalse);
    expect(roomy.spotsLabel, '6 spots left');
  });

  test('a played game is never "filling fast"', () {
    final row = apiGame(seats: 8)
      ..['joined_count'] = 7
      ..['status'] = 'completed';
    expect(GameModel.fromJson(row).isFillingFast, isFalse);
  });
}
