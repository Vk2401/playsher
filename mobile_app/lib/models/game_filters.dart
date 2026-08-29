/// When a player wants to play.
///
/// The Discover feed's date chips. `when` is sent to the API as a shorthand
/// rather than as a computed date range, because "the weekend" depends on the
/// app timezone and the server is the side that knows it — a phone set to a
/// different zone must not shift which two days a chip means.
enum GameWhen {
  anytime(null, 'Anytime'),
  today('today', 'Today'),
  tomorrow('tomorrow', 'Tomorrow'),
  weekend('weekend', 'Weekend'),
  week('week', 'This week');

  const GameWhen(this.query, this.label);

  /// The value `GET /games?when=` takes, or null for no date filter.
  final String? query;
  final String label;
}

/// Skill levels a game can be pitched at, in the order the API declares them.
enum GameLevel {
  newbie('newbie', 'Newbie'),
  beginner('beginner', 'Beginner'),
  intermediate('intermediate', 'Intermediate'),
  advanced('advanced', 'Advanced'),
  professional('professional', 'Pro'),
  ultraProfessional('ultra_professional', 'Ultra pro');

  const GameLevel(this.query, this.label);

  final String query;
  final String label;

  /// The level an API string names, or null when it names none — an unknown
  /// value is dropped rather than guessed at.
  static GameLevel? fromQuery(String? value) {
    if (value == null) return null;
    for (final l in GameLevel.values) {
      if (l.query == value) return l;
    }
    return null;
  }

  /// The label for a raw API value, falling back to the value itself so a
  /// level added on the server still renders as something readable.
  static String labelFor(String value) => fromQuery(value)?.label ?? value;
}

/// How the feed is ordered.
enum GameSort {
  soonest('soonest', 'Starting soon'),
  newest('newest', 'Just posted');

  const GameSort(this.query, this.label);

  final String query;
  final String label;
}

/// Everything the Discover feed is filtered by, as one value.
///
/// A value type so it can key a Riverpod family: two filters that describe the
/// same feed must be `==`, or every rebuild refetches.
class GameFilters {
  final int? sportId;
  final GameWhen when;
  final GameLevel? level;
  final String search;
  final String? city;

  /// Hide games that are full, already started, or called off.
  final bool onlyOpen;

  /// Hide games I host or have already joined — they live in My Games.
  final bool excludeMine;

  final GameSort sort;
  final int page;

  const GameFilters({
    this.sportId,
    this.when = GameWhen.anytime,
    this.level,
    this.search = '',
    this.city,
    this.onlyOpen = false,
    this.excludeMine = false,
    this.sort = GameSort.soonest,
    this.page = 1,
  });

  static const none = GameFilters();

  GameFilters copyWith({
    int? sportId,
    bool clearSport = false,
    GameWhen? when,
    GameLevel? level,
    bool clearLevel = false,
    String? search,
    String? city,
    bool? onlyOpen,
    bool? excludeMine,
    GameSort? sort,
    int? page,
  }) =>
      GameFilters(
        sportId: clearSport ? null : (sportId ?? this.sportId),
        when: when ?? this.when,
        level: clearLevel ? null : (level ?? this.level),
        search: search ?? this.search,
        city: city ?? this.city,
        onlyOpen: onlyOpen ?? this.onlyOpen,
        excludeMine: excludeMine ?? this.excludeMine,
        sort: sort ?? this.sort,
        page: page ?? this.page,
      );

  /// How many *optional* filters are on — what the filter button's badge shows.
  /// The search box and the sport strip are visible on screen already, so they
  /// are deliberately not counted.
  int get activeCount => [
        when != GameWhen.anytime,
        level != null,
        onlyOpen,
        sort != GameSort.soonest,
      ].where((on) => on).length;

  bool get isClean => activeCount == 0 && sportId == null && search.isEmpty;

  /// The query string `GET /games` takes. Empty values are omitted rather than
  /// sent as nulls, so the server sees the same request the user described.
  Map<String, dynamic> toQuery() => {
        'page': page,
        if (sportId != null) 'sport_id': sportId,
        if (when.query != null) 'when': when.query,
        if (level != null) 'level': level!.query,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
        if (onlyOpen) 'only_open': 'true',
        if (excludeMine) 'exclude_mine': 'true',
        'sort': sort.query,
      };

  @override
  bool operator ==(Object other) =>
      other is GameFilters &&
      other.sportId == sportId &&
      other.when == when &&
      other.level == level &&
      other.search == search &&
      other.city == city &&
      other.onlyOpen == onlyOpen &&
      other.excludeMine == excludeMine &&
      other.sort == sort &&
      other.page == page;

  @override
  int get hashCode => Object.hash(
      sportId, when, level, search, city, onlyOpen, excludeMine, sort, page);
}

/// Which half of "My games" is being asked for.
enum MyGamesScope {
  upcoming('upcoming'),
  past('past');

  const MyGamesScope(this.query);

  final String query;
}
