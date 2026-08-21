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

  /// The locality — Adambakkam, Mylapore. What players actually name when they
  /// say where they want to play.
  final String? area;
  final String? city;

  /// Covered or open-air. Decides a monsoon booking.
  final bool hasRoof;

  /// What one 30-minute slot costs at this venue.
  ///
  /// Pricing is the ground's, not the sport's — a venue with one unpriced sport
  /// used to advertise itself at zero however the rest were priced.
  final double pricePerSlot;

  /// Kilometres from the player, computed by the API when it knows where they
  /// are. Null when location is unknown or the ground has no coordinates.
  final double? distanceKm;

  /// What is left to book today, and out of how many. Both null when the day's
  /// slots have not been generated yet — which is not the same as "none left".
  final int? slotsAvailableToday;
  final int? slotsTotalToday;
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
    this.area,
    this.city,
    this.hasRoof = false,
    this.pricePerSlot = 0,
    this.distanceKm,
    this.slotsAvailableToday,
    this.slotsTotalToday,
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
      area: json['area'] as String?,
      city: json['city'] as String?,
      hasRoof: json['has_roof'] == true || json['has_roof'] == 1,
      pricePerSlot:
          double.tryParse(json['price_per_slot']?.toString() ?? '') ?? 0,
      distanceKm: double.tryParse(json['distance_km']?.toString() ?? ''),
      slotsAvailableToday: json['slots_available_today'] as int?,
      slotsTotalToday: json['slots_total_today'] as int?,
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

  /// "Adambakkam · Chennai", falling back to whichever half exists, then to
  /// the free-text address. Never a bare dash.
  String? get locality {
    final parts = [area, city]
        .map((p) => p?.trim())
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(' \u00b7 ');
    final addr = address?.trim();
    return (addr == null || addr.isEmpty) ? null : addr;
  }

  /// "4 of 14 slots left today", or null when the day is not generated.
  String? get slotsLeftLabel {
    final left = slotsAvailableToday;
    final total = slotsTotalToday;
    if (left == null || total == null || total == 0) return null;
    return '$left of $total slots left today';
  }

  bool get isFullyBookedToday =>
      slotsAvailableToday != null && slotsAvailableToday == 0;

  /// "5.2 km" — one decimal under 10km, whole numbers beyond, because nobody
  /// needs 12.3 km to a tenth.
  String? get formattedDistance {
    final d = distanceKm;
    if (d == null) return null;
    return d < 10 ? '${d.toStringAsFixed(1)} km' : '${d.round()} km';
  }

  double get avgRating {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold(0, (a, b) => a + b.rating);
    return sum / reviews.length;
  }

  /// The one price the whole app quotes: cards, detail, checkout.
  ///
  /// Deliberately *not* falling back to the old per-sport prices. The server
  /// costs a booking from `grounds.price_per_slot` alone and refuses with 409
  /// when it is 0, so a fallback here would show a figure that cannot be
  /// booked — and it read as a bug when a card said ₹200 and the detail screen
  /// said ₹0. One source, agreeing with the server, everywhere.
  double get startingPrice => pricePerSlot;

  /// Whether this venue can be booked at all. The owner has to set a price
  /// first; until then the server will not take a booking.
  bool get isBookable => pricePerSlot > 0;

  /// Null rather than "₹0" when there is no price: a venue whose owner has not
  /// set one yet cannot be booked, and quoting zero reads as free.
  String? get formattedStartingPrice {
    final price = startingPrice;
    if (price <= 0) return null;
    return '\u20b9${price.toStringAsFixed(0)}';
  }

  List<String> get sportNames => groundSports
      .map((gs) => gs.sport?.name ?? '')
      .where((n) => n.isNotEmpty)
      .toList();

  int get reviewCount => reviews.length;
}
