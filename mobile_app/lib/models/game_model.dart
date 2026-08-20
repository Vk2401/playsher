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

  factory GameModel.fromJson(Map<String, dynamic> json) {
    final gs = json['groundSport'] as Map<String, dynamic>? ??
        json['ground_sport'] as Map<String, dynamic>?;
    final sport = gs?['sport'] as Map<String, dynamic>?;
    final ground = gs?['ground'] as Map<String, dynamic>?;
    final host = json['host'] as Map<String, dynamic>? ??
        json['user'] as Map<String, dynamic>?;
    final parts = (json['participants'] as List<dynamic>?) ?? [];

    return GameModel(
      id: json['id'] as int,
      description: json['description'] as String?,
      gameDate: json['game_date'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      maxPlayers: json['max_players'] as int? ?? 10,
      currentPlayers: json['current_players'] as int? ?? 0,
      entryFee: double.tryParse(json['entry_fee']?.toString() ?? ''),
      status: json['status'] as String? ?? 'open',
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

  String get formattedFee => entryFee != null && entryFee! > 0
      ? '\u20b9${entryFee!.toStringAsFixed(0)}'
      : 'Free';
}
