class ParticipantModel {
  final int id;
  final String name;
  final String? avatar;
  final bool isHost;
  final String status;

  const ParticipantModel({
    required this.id,
    required this.name,
    this.avatar,
    this.isHost = false,
    this.status = 'joined',
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return ParticipantModel(
      id: json['id'] as int? ?? user?['id'] as int? ?? 0,
      name: user?['name'] as String? ?? json['name'] as String? ?? '',
      avatar: user?['avatar'] as String? ?? json['avatar'] as String?,
      isHost: json['is_host'] as bool? ?? false,
      status: json['status'] as String? ?? 'joined',
    );
  }

  static List<ParticipantModel> listFromJson(List<dynamic> list) =>
      list
          .map((e) => ParticipantModel.fromJson(e as Map<String, dynamic>))
          .toList();

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}
