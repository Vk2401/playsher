import 'ground_sport_model.dart';
import 'amenity_model.dart';
import 'review_model.dart';

class GroundImage {
  final int id;
  final String image;
  final bool isPrimary;

  const GroundImage(
      {required this.id, required this.image, this.isPrimary = false});

  factory GroundImage.fromJson(Map<String, dynamic> json) => GroundImage(
        id: json['id'] as int? ?? 0,
        image: json['image'] as String? ?? json['image_url'] as String? ?? '',
        isPrimary: json['is_primary'] as bool? ?? false,
      );
}

class GroundModel {
  final int id;
  final String name;
  final String? address;
  final String? city;
  final String? description;
  final String? about;
  final String? venueRules;
  final double? latitude;
  final double? longitude;
  final bool isApproved;
  final bool isActive;
  final bool isFavorite;
  final List<GroundImage> images;
  final List<GroundSportModel> groundSports;
  final List<AmenityModel> amenities;
  final List<ReviewModel> reviews;
  final String? ownerName;

  const GroundModel({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.description,
    this.about,
    this.venueRules,
    this.latitude,
    this.longitude,
    this.isApproved = true,
    this.isActive = true,
    this.isFavorite = false,
    this.images = const [],
    this.groundSports = const [],
    this.amenities = const [],
    this.reviews = const [],
    this.ownerName,
  });

  factory GroundModel.fromJson(Map<String, dynamic> json) {
    // Handle images: 'images' or 'slider_images' (backend)
    final imgs = (json['images'] as List<dynamic>?) ??
        (json['slider_images'] as List<dynamic>?) ??
        [];

    // Handle ground sports: 'ground_sports' or build from 'category'
    List<dynamic> sports = (json['groundSports'] as List<dynamic>?) ??
        (json['ground_sports'] as List<dynamic>?) ??
        [];
    if (sports.isEmpty && json['category'] != null) {
      // Backend returns category as the sport for this ground
      sports = [
        {
          'id': json['id'],
          'ground_id': json['id'],
          'sport': json['category'],
          'price_per_slot': json['cost_per_hr'],
          'currency': '\u20b9',
        }
      ];
    }

    // Handle amenities: 'amenities' or merge 'facilities' + 'features'
    List<dynamic> amens = (json['amenities'] as List<dynamic>?) ?? [];
    if (amens.isEmpty) {
      final facilities = (json['facilities'] as List<dynamic>?) ?? [];
      final features = (json['features'] as List<dynamic>?) ?? [];
      amens = [...facilities, ...features];
    }

    final revs = (json['reviews'] as List<dynamic>?) ?? [];
    final owner = json['owner'] as Map<String, dynamic>? ??
        json['vendor'] as Map<String, dynamic>?;

    return GroundModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      city: json['city'] as String?,
      description: json['description'] as String?,
      about: json['about'] as String?,
      venueRules: json['venue_rules'] as String?,
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      isApproved: json['is_approved'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? json['status'] == 'Active',
      isFavorite: json['is_favorite'] as bool? ?? false,
      images: imgs
          .map((e) => GroundImage.fromJson(e as Map<String, dynamic>))
          .toList(),
      groundSports: GroundSportModel.listFromJson(sports),
      amenities: AmenityModel.listFromJson(amens),
      reviews: ReviewModel.listFromJson(revs),
      ownerName: owner?['name'] as String?,
    );
  }

  static List<GroundModel> listFromJson(List<dynamic> list) =>
      list.map((e) => GroundModel.fromJson(e as Map<String, dynamic>)).toList();

  String? get primaryImageUrl {
    if (images.isEmpty) return null;
    final primary = images.where((i) => i.isPrimary).toList();
    return primary.isNotEmpty ? primary.first.image : images.first.image;
  }

  double get avgRating {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold(0, (a, b) => a + b.rating);
    return sum / reviews.length;
  }

  double get startingPrice {
    if (groundSports.isEmpty) return 0;
    final prices = groundSports.map((gs) => gs.pricePerSlot).toList()..sort();
    return prices.first;
  }

  String get formattedStartingPrice {
    if (groundSports.isEmpty) return '';
    return '\u20b9${startingPrice.toStringAsFixed(0)}';
  }

  List<String> get sportNames => groundSports
      .map((gs) => gs.sport?.name ?? '')
      .where((n) => n.isNotEmpty)
      .toList();

  int get reviewCount => reviews.length;
}
