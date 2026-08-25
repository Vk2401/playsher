class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  /// Where the app should go when this row is tapped, as a router path.
  /// The server sends a path rather than a URL so each client prefixes its own.
  final String? actionPath;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'general',
    this.isRead = false,
    required this.createdAt,
    this.actionPath,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        type: json['type'] as String? ?? 'general',
        // MySQL stores this as TINYINT(1); a driver that hands back 0/1
        // rather than a bool must not silently mark everything unread.
        isRead: json['is_read'] == true || json['is_read'] == 1,
        actionPath: json['action_path'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
      );

  static List<NotificationModel> listFromJson(List<dynamic> list) => list
      .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
      .toList();

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        title: title,
        message: message,
        type: type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        actionPath: actionPath,
      );

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
