import 'participant_model.dart';

class GameModel {
  final int id;
  final String? description;
  final String? gameDate;
  final String? startTime;
  final String? endTime;
  final int maxPlayers;
  final int currentPlayers;
  final double? entryFee;
  final String status;
  final String? sportName;
  final String? groundName;
  final String? groundCity;
  final String? groundAddress;
  final String? hostName;
  final String? hostAvatar;
  final String? gameLevel;
  final String? visibility;
  final String? gameName;
  final List<ParticipantModel> participants;

  const GameModel({
    required this.id,
    this.description,
    this.gameDate,
    this.startTime,
    this.endTime,
    this.maxPlayers = 10,
    this.currentPlayers = 0,
    this.entryFee,
    this.status = 'open',
    this.sportName,
    this.groundName,
    this.groundCity,
    this.groundAddress,
    this.hostName,
    this.hostAvatar,
    this.gameLevel,
    this.visibility,
    this.gameName,
    this.participants = const [],
  });

  /// Maps the shape `GET /games` actually returns.
  ///
  /// A game carries no schedule or money of its own — it is hosted on a
  /// booking, and the date, times, venue and total all live there. This model
  /// previously read `game_date`, `max_players`, `entry_fee` and a top-level
  /// `groundSport`, none of which the API has ever sent, so every game rendered
  /// with no date, no venue and a fee of zero.
  factory GameModel.fromJson(Map<String, dynamic> json) {
    final booking = json['booking'] as Map<String, dynamic>?;
    final gs = booking?['groundSport'] as Map<String, dynamic>? ??
        json['groundSport'] as Map<String, dynamic>? ??
        json['ground_sport'] as Map<String, dynamic>?;
    final sport = gs?['sport'] as Map<String, dynamic>?;
    final ground = gs?['ground'] as Map<String, dynamic>?;
    final host = json['hostedByUser'] as Map<String, dynamic>? ??
        json['host'] as Map<String, dynamic>? ??
        json['user'] as Map<String, dynamic>?;
    final parts = (json['participants'] as List<dynamic>?) ?? [];

    // Only participants who actually hold a seat count toward the fill bar.
    final joined = parts.where((p) {
      final status = (p as Map<String, dynamic>)['status']?.toString();
      return status == null || status == 'accepted' || status == 'joined';
    }).length;

    return GameModel(
      id: json['id'] as int,
      description: json['description'] as String?,
      gameDate:
          booking?['slot_date'] as String? ?? json['game_date'] as String?,
      startTime: booking?['slot_time_from'] as String? ??
          json['start_time'] as String?,
      endTime:
          booking?['slot_time_to'] as String? ?? json['end_time'] as String?,
      maxPlayers:
          json['max_participants'] as int? ?? json['max_players'] as int? ?? 10,
      currentPlayers: json['current_players'] as int? ?? joined,
      // Server-computed share of the booking total. Money is never derived here.
      entryFee: double.tryParse(json['price_per_player']?.toString() ?? '') ??
          double.tryParse(json['entry_fee']?.toString() ?? ''),
      status: json['status'] as String? ??
          ((json['is_active'] as bool? ?? true) ? 'open' : 'closed'),
      sportName: sport?['name'] as String? ?? json['sport_name'] as String?,
      groundName: ground?['name'] as String? ?? json['ground_name'] as String?,
      groundCity: ground?['city'] as String? ?? json['ground_city'] as String?,
      groundAddress:
          ground?['address'] as String? ?? json['ground_address'] as String?,
      hostName: host?['name'] as String? ?? json['host_name'] as String?,
      hostAvatar: host?['avatar'] as String? ?? json['host_avatar'] as String?,
      gameLevel:
          json['game_level'] as String? ?? json['skill_level'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      gameName: json['game_name'] as String? ?? json['name'] as String?,
      participants: ParticipantModel.listFromJson(parts),
    );
  }

  static List<GameModel> listFromJson(List<dynamic> list) =>
      list.map((e) => GameModel.fromJson(e as Map<String, dynamic>)).toList();

  int get spotsLeft => maxPlayers - currentPlayers;
  bool get isFull => spotsLeft <= 0;

  String get date => gameDate ?? 'TBD';
  String get time => startTime != null
      ? (endTime != null ? '$startTime – $endTime' : startTime!)
      : 'TBD';
  String get skillLevel => gameLevel ?? '';

  double get fillRate => maxPlayers > 0 ? currentPlayers / maxPlayers : 0;

  /// Per-player share, or a dash when the booking carried no total — never
  /// "Free", which would be a claim the API did not make.
  String get formattedFee {
    final fee = entryFee;
    if (fee == null) return '\u2014';
    if (fee <= 0) return 'Free';
    return '\u20b9${fee.toStringAsFixed(0)}';
  }
}
