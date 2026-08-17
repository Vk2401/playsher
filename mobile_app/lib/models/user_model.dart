class UserModel {
  final int id;
  final String name;
  final String mobile;
  final String? email;
  final String? city;
  final String? avatar;
  final int gamesPlayed;
  final double rating;

  const UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    this.email,
    this.city,
    this.avatar,
    this.gamesPlayed = 0,
    this.rating = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? json['phone'] as String? ?? '',
        email: json['email'] as String?,
        city: json['city'] as String?,
        avatar: json['avatar'] as String? ?? json['profile_photo'] as String? ?? json['photo'] as String?,
        gamesPlayed: json['games_played'] as int? ?? 0,
        rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'email': email,
        'city': city,
        'avatar': avatar,
        'games_played': gamesPlayed,
        'rating': rating,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}
