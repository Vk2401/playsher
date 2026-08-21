import 'ground_model.dart';

/// Everything the filter sheet can set.
///
/// A value class with real equality, because it is both the thing the filter
/// screen returns through `context.pop` and part of a Riverpod family key —
/// without `==` the grounds provider would refetch on every rebuild.
///
/// The API can only narrow by sport, roof and radius; price, rating and
/// amenities have no server-side support, so [apply] does those in memory over
/// the page that came back. That is a real limit, not a design: it filters the
/// current page only, the same caveat the backend's nearby search carries.
class VenueFilters {
  final Set<int> sportIds;
  final double minPrice;
  final double maxPrice;

  /// Kilometres. Null means "any distance".
  final double? maxDistanceKm;

  /// Null means "any rating".
  final double? minRating;

  final Set<int> amenityIds;

  /// Null means "either"; true covered only, false open-air only.
  final bool? hasRoof;

  static const priceFloor = 0.0;
  static const priceCeiling = 5000.0;

  const VenueFilters({
    this.sportIds = const {},
    this.minPrice = priceFloor,
    this.maxPrice = priceCeiling,
    this.maxDistanceKm,
    this.minRating,
    this.amenityIds = const {},
    this.hasRoof,
  });

  static const none = VenueFilters();

  bool get priceIsDefault =>
      minPrice <= priceFloor && maxPrice >= priceCeiling;

  /// How many filters are actually narrowing anything — drives the badge on
  /// the filter button and the count on the apply CTA.
  int get activeCount {
    var n = 0;
    if (sportIds.isNotEmpty) n += 1;
    if (!priceIsDefault) n += 1;
    if (maxDistanceKm != null) n += 1;
    if (minRating != null) n += 1;
    if (amenityIds.isNotEmpty) n += 1;
    if (hasRoof != null) n += 1;
    return n;
  }

  bool get isEmpty => activeCount == 0;

  VenueFilters copyWith({
    Set<int>? sportIds,
    double? minPrice,
    double? maxPrice,
    Object? maxDistanceKm = _unset,
    Object? minRating = _unset,
    Set<int>? amenityIds,
    Object? hasRoof = _unset,
  }) =>
      VenueFilters(
        sportIds: sportIds ?? this.sportIds,
        minPrice: minPrice ?? this.minPrice,
        maxPrice: maxPrice ?? this.maxPrice,
        // A sentinel, so passing null genuinely clears these rather than being
        // read as "leave unchanged".
        maxDistanceKm: maxDistanceKm == _unset
            ? this.maxDistanceKm
            : maxDistanceKm as double?,
        minRating: minRating == _unset ? this.minRating : minRating as double?,
        amenityIds: amenityIds ?? this.amenityIds,
        hasRoof: hasRoof == _unset ? this.hasRoof : hasRoof as bool?,
      );

  /// The filters the server cannot apply, run over what it returned.
  List<GroundModel> apply(List<GroundModel> grounds) {
    return grounds.where((g) {
      if (!priceIsDefault) {
        final price = g.startingPrice;
        // A ground with no pricing is kept: hiding it would silently drop
        // venues whose owner has not set a price yet.
        if (price > 0 && (price < minPrice || price > maxPrice)) return false;
      }

      if (minRating != null && g.avgRating < minRating!) return false;

      if (amenityIds.isNotEmpty) {
        final ids = g.amenities.map((a) => a.id).toSet();
        // Every selected amenity must be present — "with parking AND showers"
        // is what a player means by ticking both.
        if (!amenityIds.every(ids.contains)) return false;
      }

      return true;
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is VenueFilters &&
      _sameSet(other.sportIds, sportIds) &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.maxDistanceKm == maxDistanceKm &&
      other.minRating == minRating &&
      _sameSet(other.amenityIds, amenityIds) &&
      other.hasRoof == hasRoof;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(sportIds),
        minPrice,
        maxPrice,
        maxDistanceKm,
        minRating,
        Object.hashAllUnordered(amenityIds),
        hasRoof,
      );

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

const Object _unset = Object();
