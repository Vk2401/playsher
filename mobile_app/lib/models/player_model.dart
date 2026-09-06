/// Another player, as this app sees them.
///
/// Two shapes, because the API sends two: a [PlayerCard] wherever somebody
/// appears beside something else — a search result, a squad row, a follower
/// list — and a [PlayerProfile] for the screen that is about them.
///
/// Neither carries a phone number or an email, because the API does not send
/// them. A mobile number is how you *find* an account you already have the
/// number for; it is never something the app receives back.
library;

/// The smallest honest identity: who this is, and whether you follow them.
class PlayerCard {
  final int id;
  final String? username;
  final String name;
  final String? avatar;

  /// Whether the signed-in player follows this one. Null when the API did not
  /// say — a follow button binds to `false`, never to "unknown".
  final bool isFollowing;

  /// This is me. The list still shows the row; it just offers no follow button.
  final bool isSelf;

  /// How many games we have both been in. Only sent by the teammates list.
  final int? gamesTogether;

  const PlayerCard({
    required this.id,
    required this.name,
    this.username,
    this.avatar,
    this.isFollowing = false,
    this.isSelf = false,
    this.gamesTogether,
  });

  factory PlayerCard.fromJson(Map<String, dynamic> json) => PlayerCard(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        username: json['username'] as String?,
        avatar: json['profile_picture'] as String? ?? json['avatar'] as String?,
        isFollowing: json['is_following'] as bool? ?? false,
        isSelf: json['is_self'] as bool? ?? false,
        gamesTogether: json['games_together'] as int?,
      );

  static List<PlayerCard> listFromJson(List<dynamic> list) => list
      .map((e) => PlayerCard.fromJson(e as Map<String, dynamic>))
      .toList();

  PlayerCard copyWith({bool? isFollowing}) => PlayerCard(
        id: id,
        name: name,
        username: username,
        avatar: avatar,
        isFollowing: isFollowing ?? this.isFollowing,
        isSelf: isSelf,
        gamesTogether: gamesTogether,
      );

  /// `@ravi99`, or the display name when the API sent no handle.
  String get handle =>
      username == null || username!.isEmpty ? name : '@$username';

  String get initials => _initialsOf(name);

  /// The line under the name in a list: the handle, plus how well you know them.
  String get subtitle {
    final shared = gamesTogether;
    if (shared != null && shared > 0) {
      return '$handle · $shared ${shared == 1 ? 'game' : 'games'} together';
    }
    return handle;
  }
}

/// A player's own screen: who they are, and what they have played.
class PlayerProfile {
  final int id;
  final String? username;
  final String name;
  final String? avatar;
  final String? bio;
  final String? memberSince;

  final int followersCount;
  final int followingCount;
  final int gamesHosted;
  final int gamesPlayed;

  /// The sports they picked, so a profile says something before they have
  /// played a single game.
  final List<PlayerSport> sports;

  final bool isSelf;
  final bool isFollowing;

  /// They follow you but you do not follow them — the prompt for "follow back".
  final bool followsYou;

  const PlayerProfile({
    required this.id,
    required this.name,
    this.username,
    this.avatar,
    this.bio,
    this.memberSince,
    this.followersCount = 0,
    this.followingCount = 0,
    this.gamesHosted = 0,
    this.gamesPlayed = 0,
    this.sports = const [],
    this.isSelf = false,
    this.isFollowing = false,
    this.followsYou = false,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        username: json['username'] as String?,
        avatar: json['profile_picture'] as String? ?? json['avatar'] as String?,
        bio: json['bio'] as String?,
        memberSince: json['member_since']?.toString(),
        followersCount: json['followers_count'] as int? ?? 0,
        followingCount: json['following_count'] as int? ?? 0,
        gamesHosted: json['games_hosted'] as int? ?? 0,
        gamesPlayed: json['games_played'] as int? ?? 0,
        sports: ((json['sports'] as List<dynamic>?) ?? [])
            .map((e) => PlayerSport.fromJson(e as Map<String, dynamic>))
            .toList(),
        isSelf: json['is_self'] as bool? ?? false,
        isFollowing: json['is_following'] as bool? ?? false,
        followsYou: json['follows_you'] as bool? ?? false,
      );

  PlayerProfile copyWith({bool? isFollowing, int? followersCount}) =>
      PlayerProfile(
        id: id,
        name: name,
        username: username,
        avatar: avatar,
        bio: bio,
        memberSince: memberSince,
        followersCount: followersCount ?? this.followersCount,
        followingCount: followingCount,
        gamesHosted: gamesHosted,
        gamesPlayed: gamesPlayed,
        sports: sports,
        isSelf: isSelf,
        isFollowing: isFollowing ?? this.isFollowing,
        followsYou: followsYou,
      );

  String get handle =>
      username == null || username!.isEmpty ? name : '@$username';

  String get initials => _initialsOf(name);

  /// "Playing since Sep 2026" — a small trust signal on a stranger's profile.
  String? get memberSinceLabel {
    final raw = memberSince;
    if (raw == null || raw.isEmpty) return null;
    final at = DateTime.tryParse(raw);
    if (at == null) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Playing since ${months[at.month - 1]} ${at.year}';
  }

  /// The card view of the same person, for a list that shows both.
  PlayerCard get asCard => PlayerCard(
        id: id,
        name: name,
        username: username,
        avatar: avatar,
        isFollowing: isFollowing,
        isSelf: isSelf,
      );
}

/// A sport a player says they play.
class PlayerSport {
  final int id;
  final String name;
  final String? image;

  const PlayerSport({required this.id, required this.name, this.image});

  factory PlayerSport.fromJson(Map<String, dynamic> json) => PlayerSport(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        image: json['image'] as String?,
      );
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
