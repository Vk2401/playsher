import 'game_filters.dart';
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
  final double? totalAmount;

  /// Server-derived: `open` · `full` · `in_progress` · `completed` ·
  /// `cancelled`. Never computed here — a card that decides for itself whether
  /// a game is still open will disagree with the endpoint that refuses the
  /// join.
  final String status;

  final String? sportName;
  final int? sportId;
  final String? groundName;
  final String? groundArea;
  final String? groundCity;
  final String? groundAddress;
  final int? groundId;

  /// The venue's coordinates, so the detail screen can offer directions. Null
  /// when the owner never set them — the affordance is hidden rather than
  /// opening a map on the null island.
  final double? groundLatitude;
  final double? groundLongitude;
  final String? hostName;
  final String? hostAvatar;
  final String? gameLevel;
  final String? visibility;
  final String? gameName;

  /// The viewer's own relationship to this game, as the API sees it.
  final bool isHost;
  final bool isJoined;
  final bool isInvited;

  /// `hosting` | `playing` on rows from `GET /games/mine`; null elsewhere.
  final String? relation;

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
    this.totalAmount,
    this.status = 'open',
    this.sportName,
    this.sportId,
    this.groundName,
    this.groundArea,
    this.groundCity,
    this.groundAddress,
    this.groundId,
    this.groundLatitude,
    this.groundLongitude,
    this.hostName,
    this.hostAvatar,
    this.gameLevel,
    this.visibility,
    this.gameName,
    this.isHost = false,
    this.isJoined = false,
    this.isInvited = false,
    this.relation,
    this.participants = const [],
  });

  /// Maps the shape `GET /games` actually returns.
  ///
  /// A game carries no schedule or money of its own — it is hosted on a
  /// booking, and the date, times, venue and total all live there. The API now
  /// also flattens those onto the row and adds the seat count, the derived
  /// status and the viewer's own relationship to the game; the nested reads are
  /// kept as the fallback so an older payload still renders.
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

    final seats =
        json['max_participants'] as int? ?? json['max_players'] as int? ?? 10;

    return GameModel(
      id: json['id'] as int,
      description: json['description'] as String?,
      gameDate: json['slot_date'] as String? ??
          booking?['slot_date'] as String? ??
          json['game_date'] as String?,
      startTime: json['slot_time_from'] as String? ??
          booking?['slot_time_from'] as String? ??
          json['start_time'] as String?,
      endTime: json['slot_time_to'] as String? ??
          booking?['slot_time_to'] as String? ??
          json['end_time'] as String?,
      maxPlayers: seats,
      currentPlayers: json['joined_count'] as int? ??
          json['current_players'] as int? ??
          joined,
      // Server-computed share of the booking total. Money is never derived here.
      entryFee: double.tryParse(json['price_per_player']?.toString() ?? '') ??
          double.tryParse(json['entry_fee']?.toString() ?? ''),
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '') ??
          double.tryParse(booking?['total_amount']?.toString() ?? ''),
      status: json['status'] as String? ??
          ((json['is_active'] as bool? ?? true) ? 'open' : 'cancelled'),
      sportName: json['sport_name'] as String? ?? sport?['name'] as String?,
      sportId: json['sport_id'] as int? ?? sport?['id'] as int?,
      groundName: json['ground_name'] as String? ?? ground?['name'] as String?,
      groundArea: json['ground_area'] as String? ?? ground?['area'] as String?,
      groundCity: json['ground_city'] as String? ?? ground?['city'] as String?,
      groundAddress:
          json['ground_address'] as String? ?? ground?['address'] as String?,
      groundId: json['ground_id'] as int? ?? ground?['id'] as int?,
      groundLatitude: double.tryParse(ground?['latitude']?.toString() ?? ''),
      groundLongitude: double.tryParse(ground?['longitude']?.toString() ?? ''),
      hostName: json['host_name'] as String? ?? host?['name'] as String?,
      hostAvatar: json['host_avatar'] as String? ??
          host?['profile_picture'] as String? ??
          host?['avatar'] as String?,
      gameLevel:
          json['game_level'] as String? ?? json['skill_level'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      gameName: json['game_name'] as String? ?? json['name'] as String?,
      isHost: json['is_host'] as bool? ?? false,
      isJoined: json['is_joined'] as bool? ?? false,
      isInvited: json['is_invited'] as bool? ?? false,
      relation: json['relation'] as String?,
      participants: ParticipantModel.listFromJson(parts),
    );
  }

  static List<GameModel> listFromJson(List<dynamic> list) =>
      list.map((e) => GameModel.fromJson(e as Map<String, dynamic>)).toList();

  // ── Seats ──────────────────────────────────────────────────────────────────

  int get spotsLeft => (maxPlayers - currentPlayers).clamp(0, maxPlayers);
  bool get isFull => status == 'full' || spotsLeft <= 0;
  double get fillRate => maxPlayers > 0 ? currentPlayers / maxPlayers : 0;

  /// A game filling up is the one worth tapping first, so the card says so —
  /// but only while there is still a seat and the game has not started.
  bool get isFillingFast => isOpen && spotsLeft > 0 && spotsLeft <= 2;

  /// "3 spots left" / "Last spot" / "Full" — the seat line, in words rather
  /// than by the colour of a bar alone.
  String get spotsLabel {
    if (isFull) return 'Full';
    if (spotsLeft == 1) return 'Last spot';
    return '$spotsLeft spots left';
  }

  // ── Status ─────────────────────────────────────────────────────────────────

  bool get isOpen => status == 'open';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isPast => isCompleted || isCancelled;
  bool get isPrivate => visibility == 'private';

  /// Can *this viewer* still take a seat?
  bool get canJoin => isOpen && !isHost && !isJoined;

  /// A sentence for the state the game is in, for a badge or a disabled CTA.
  String get statusLabel => switch (status) {
        'full' => 'Full',
        'in_progress' => 'Playing now',
        'completed' => 'Played',
        'cancelled' => 'Cancelled',
        _ => 'Open',
      };

  // ── When ───────────────────────────────────────────────────────────────────

  /// The game's kick-off as a local `DateTime`, or null when the API sent no
  /// parseable date. Built from the wall-clock strings the booking carries —
  /// they are already in the venue's own timezone, so they are read as local
  /// rather than converted.
  DateTime? get startsAt {
    final date = gameDate;
    if (date == null || date.isEmpty) return null;
    final day = DateTime.tryParse(date.length > 10 ? date.substring(0, 10) : date);
    if (day == null) return null;
    final parts = (startTime ?? '00:00').split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// "Today" · "Tomorrow" · "Sat, 14 Sep" — the line a player scans first.
  String get dayLabel {
    final at = startsAt;
    if (at == null) return gameDate ?? 'Date TBD';
    final now = DateTime.now();
    final days = DateTime(at.year, at.month, at.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    return '${_weekdays[at.weekday - 1]}, ${at.day} ${_months[at.month - 1]}';
  }

  /// "6:00 PM – 7:00 PM", or just the start when no end came back.
  String get timeLabel {
    final from = _clock(startTime);
    final to = _clock(endTime);
    if (from == null) return 'Time TBD';
    return to == null ? from : '$from – $to';
  }

  /// "Today · 6:00 PM" — day and time on one line, for a dense card.
  String get whenLabel => '$dayLabel · ${_clock(startTime) ?? 'TBD'}';

  /// "Starts in 2h" / "Starts in 3 days" — urgency, only while it is true.
  String? get countdownLabel {
    final at = startsAt;
    if (at == null || !isOpen) return null;
    final delta = at.difference(DateTime.now());
    if (delta.isNegative) return null;
    if (delta.inHours < 1) return 'Starts in ${delta.inMinutes}m';
    if (delta.inHours < 24) return 'Starts in ${delta.inHours}h';
    if (delta.inDays == 1) return 'Starts tomorrow';
    return 'Starts in ${delta.inDays} days';
  }

  static String? _clock(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '');
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    if (h == null) return raw;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:${m.toString().padLeft(2, '0')} $suffix';
  }

  // ── Where ──────────────────────────────────────────────────────────────────

  /// "Adyar, Chennai" — the shortest true description of where this is.
  String get locationLabel => [groundArea, groundCity]
      .whereType<String>()
      .where((s) => s.trim().isNotEmpty)
      .join(', ');

  /// The title a card shows: the host's own name for the game, or the venue.
  String get displayTitle =>
      gameName?.trim().isNotEmpty == true
          ? gameName!
          : '${sportName ?? 'Game'} at ${groundName ?? 'a ground'}';

  // ── Money ──────────────────────────────────────────────────────────────────

  String get skillLevel => gameLevel ?? '';

  /// "Intermediate" rather than "intermediate" — the label the level enum
  /// declares, so the app and the host form cannot drift apart.
  String get levelLabel =>
      gameLevel == null ? '' : GameLevel.labelFor(gameLevel!);

  /// Per-player share, or a dash when the booking carried no total — never
  /// "Free", which would be a claim the API did not make.
  String get formattedFee {
    final fee = entryFee;
    if (fee == null) return '—';
    if (fee <= 0) return 'Free';
    return '₹${fee.toStringAsFixed(0)}';
  }

  /// Kept for the older callers that read `date` / `time` directly.
  String get date => gameDate ?? 'TBD';
  String get time => timeLabel;
}
