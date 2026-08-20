class CoachModel {
  final int id;
  final String name;
  final String? bio;
  final int experience;
  final double hourlyRate;
  final String? photo;
  final double rating;
  final int reviewCount;
  final String? sportName;
  final String? location;
  final List<String> expertiseTags;

  const CoachModel({
    required this.id,
    required this.name,
    this.bio,
    this.experience = 0,
    this.hourlyRate = 0,
    this.photo,
    this.rating = 0,
    this.reviewCount = 0,
    this.sportName,
    this.location,
    this.expertiseTags = const [],
  });

  factory CoachModel.fromJson(Map<String, dynamic> json) {
    final tags = (json['expertise_tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return CoachModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      bio: json['bio'] as String?,
      experience: json['experience'] as int? ?? 0,
      hourlyRate: double.tryParse(json['hourly_rate']?.toString() ?? '0') ?? 0,
      photo: json['photo'] as String?,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      sportName: json['sport_name'] as String? ??
          (json['sport'] as Map<String, dynamic>?)?['name'] as String?,
      location: json['location'] as String?,
      expertiseTags: tags,
    );
  }

  static List<CoachModel> listFromJson(List<dynamic> list) =>
      list.map((e) => CoachModel.fromJson(e as Map<String, dynamic>)).toList();

  String get formattedRate => '\u20b9${hourlyRate.toStringAsFixed(0)}/hr';

  String get experienceLabel =>
      '$experience ${experience == 1 ? 'year' : 'years'}';
}
