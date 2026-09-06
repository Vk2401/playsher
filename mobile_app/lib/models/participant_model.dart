class ParticipantModel {
  /// The participant row's own id — not the player's.
  final int id;

  /// The player behind the seat, so a squad member can be tapped through to
  /// their profile and invited to the next game.
  final int? userId;
  final String? username;

  final String name;
  final String? avatar;
  final bool isHost;
  final String status;

  const ParticipantModel({
    required this.id,
    this.userId,
    this.username,
    required this.name,
    this.avatar,
    this.isHost = false,
    this.status = 'joined',
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return ParticipantModel(
      id: json['id'] as int? ?? user?['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? user?['id'] as int?,
      username: user?['username'] as String? ?? json['username'] as String?,
      name: user?['name'] as String? ?? json['name'] as String? ?? '',
      // `profile_picture` is what the API sends; `avatar` is the older name.
      avatar: user?['profile_picture'] as String? ??
          user?['avatar'] as String? ??
          json['avatar'] as String?,
      isHost: json['is_host'] as bool? ?? false,
      status: json['status'] as String? ?? 'joined',
    );
  }

  static List<ParticipantModel> listFromJson(List<dynamic> list) => list
      .map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>))
      .toList();

  /// What a profile link needs: the handle if there is one, else the user id.
  String? get handle => username?.isNotEmpty == true
      ? username
      : (userId != null ? '$userId' : null);

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}
