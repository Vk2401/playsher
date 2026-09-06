class UserModel {
  final int id;
  final String name;

  /// The handle this account is found and invited by.
  ///
  /// Every account gets one at registration, and one that predates handles is
  /// backfilled the first time its profile is read — so in practice this is
  /// always set. Nullable only because the API's column is.
  final String? username;

  final String? bio;
  final String mobile;
  final String? email;
  final String? city;
  final String? avatar;
  final int gamesPlayed;
  final int gamesHosted;
  final int followersCount;
  final int followingCount;
  final double rating;

  const UserModel({
    required this.id,
    required this.name,
    this.username,
    this.bio,
    required this.mobile,
    this.email,
    this.city,
    this.avatar,
    this.gamesPlayed = 0,
    this.gamesHosted = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.rating = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        username: json['username'] as String?,
        bio: json['bio'] as String?,
        mobile: json['mobile'] as String? ?? json['phone'] as String? ?? '',
        email: json['email'] as String?,
        city: json['city'] as String?,
        // `profile_picture` is the column the API actually sends; the rest are
        // older names kept so a cached payload still renders an avatar.
        avatar: json['profile_picture'] as String? ??
            json['avatar'] as String? ??
            json['profile_photo'] as String? ??
            json['photo'] as String?,
        gamesPlayed: json['games_played'] as int? ?? 0,
        gamesHosted: json['games_hosted'] as int? ?? 0,
        followersCount: json['followers_count'] as int? ?? 0,
        followingCount: json['following_count'] as int? ?? 0,
        rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'bio': bio,
        'mobile': mobile,
        'email': email,
        'city': city,
        'profile_picture': avatar,
        'games_played': gamesPlayed,
        'games_hosted': gamesHosted,
        'followers_count': followersCount,
        'following_count': followingCount,
        'rating': rating,
      };

  /// The handle as it is written and read: `@ravi99`.
  ///
  /// Falls back to the display name only when the API sent no handle at all,
  /// so the UI never renders a bare `@`.
  String get handle => username == null || username!.isEmpty ? name : '@$username';

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}
