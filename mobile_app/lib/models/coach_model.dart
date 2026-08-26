/// A venue where a coach is approved to hold sessions.
///
/// Only grounds whose owner approved the coach reach the app — the API filters
/// on that — so anything in this list is a place the customer may actually pick.
class CoachVenue {
  final int id;
  final String name;
  final String? area;
  final String? city;
  final String? image;

  const CoachVenue({
    required this.id,
    required this.name,
    this.area,
    this.city,
    this.image,
  });

  factory CoachVenue.fromJson(Map<String, dynamic> json) => CoachVenue(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        area: json['area'] as String?,
        city: json['city'] as String?,
        image: _primaryImage(json['images']),
      );

  /// The ground's primary image, falling back to its first.
  ///
  /// Walked by hand rather than with `firstWhere(orElse:)`: the decoded list's
  /// runtime element type is whatever the JSON produced, and an `orElse` that
  /// returns `dynamic` throws a type error against a more specific list — a
  /// crash in the one case the fallback exists for.
  static String? _primaryImage(Object? images) {
    if (images is! List) return null;
    Map<String, dynamic>? chosen;
    for (final entry in images) {
      if (entry is! Map) continue;
      final image = entry.cast<String, dynamic>();
      chosen ??= image;
      if (image['is_primary'] == true) {
        chosen = image;
        break;
      }
    }
    return chosen?['image'] as String?;
  }

  /// "Indiranagar, Bengaluru", or whichever half exists.
  String get locality =>
      [area, city].where((p) => p != null && p.isNotEmpty).join(', ');
}

class CoachModel {
  final int id;
  final String name;
  final String? about;
  final int experienceYears;

  /// What one 30-minute block costs. Zero means the coach has not priced
  /// themselves — the API refuses to book them, and the app says
  /// "Price on request" rather than "₹0", which reads as free.
  final double pricePerSlot;

  final String? photo;
  final double rating;
  final int reviewCount;
  final String? sportName;
  final String? city;
  final String? level;
  final String? experienceDetails;
  final String? awards;
  final List<String> expertiseTags;
  final List<CoachVenue> venues;

  const CoachModel({
    required this.id,
    required this.name,
    this.about,
    this.experienceYears = 0,
    this.pricePerSlot = 0,
    this.photo,
    this.rating = 0,
    this.reviewCount = 0,
    this.sportName,
    this.city,
    this.level,
    this.experienceDetails,
    this.awards,
    this.expertiseTags = const [],
    this.venues = const [],
  });

  factory CoachModel.fromJson(Map<String, dynamic> json) {
    final sport = json['sport'] as Map<String, dynamic>?;

    // `qualities` is free text the coach writes; a comma-separated line is how
    // it is entered in practice, so it renders as chips rather than a wall.
    final qualities = (json['qualities'] as String?)
            ?.split(RegExp(r'[,\n]'))
            .map((q) => q.trim())
            .where((q) => q.isNotEmpty)
            .toList() ??
        const <String>[];

    final links = json['groundLinks'];
    final venues = <CoachVenue>[];
    if (links is List) {
      for (final link in links) {
        if (link is! Map) continue;
        final ground = link['ground'];
        if (ground is Map) {
          venues.add(CoachVenue.fromJson(ground.cast<String, dynamic>()));
        }
      }
    }

    return CoachModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      about: json['about'] as String?,
      experienceYears: json['experience_years'] as int? ?? 0,
      pricePerSlot:
          double.tryParse(json['price_per_slot']?.toString() ?? '0') ?? 0,
      photo: json['profile_picture'] as String?,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      sportName: sport?['name'] as String? ?? json['sport_name'] as String?,
      city: json['city'] as String?,
      level: json['level'] as String?,
      experienceDetails: json['experience_details'] as String?,
      awards: json['awards'] as String?,
      expertiseTags: qualities,
      venues: venues,
    );
  }

  static List<CoachModel> listFromJson(List<dynamic> list) =>
      list.map((e) => CoachModel.fromJson(e as Map<String, dynamic>)).toList();

  /// A coach with no price cannot be booked — the create endpoint answers 409.
  bool get isBookable => pricePerSlot > 0;

  /// Per half hour, because that is the unit the whole product prices in.
  String get formattedRate => isBookable
      ? '₹${pricePerSlot.toStringAsFixed(0)}'
      : 'Price on request';

  String get rateCaption => isBookable ? 'per 30 min' : 'Not set yet';

  /// What an hour costs, for the line customers actually compare on.
  String get formattedHourlyRate => isBookable
      ? '₹${(pricePerSlot * 2).toStringAsFixed(0)}/hr'
      : 'Price on request';

  String get experienceLabel =>
      '$experienceYears ${experienceYears == 1 ? 'year' : 'years'}';

  /// Where this coach works, for a card's subtitle.
  String? get locality {
    if (venues.isNotEmpty) return venues.first.locality;
    return city;
  }
}
