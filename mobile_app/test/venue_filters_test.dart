import 'package:flutter_test/flutter_test.dart';
import 'package:playsher_app/models/ground_model.dart';
import 'package:playsher_app/models/venue_filters.dart';

GroundModel ground({
  int id = 1,
  double price = 500,
  double rating = 0,
  List<int> amenityIds = const [],
  String? area,
  String? city,
  String? address,
  bool hasRoof = false,
  double? distanceKm,
  int? left,
  int? total,
}) =>
    GroundModel.fromJson({
      'id': id,
      'name': 'Ground $id',
      'area': area,
      'city': city,
      'address': address,
      'has_roof': hasRoof,
      // Pricing is the venue's; the filter reads it from here.
      'price_per_slot': '$price',
      'distance_km': distanceKm,
      'slots_available_today': left,
      'slots_total_today': total,
      'groundSports': [
        {'id': id, 'sport': {'id': 1, 'name': 'Cricket'}}
      ],
      'amenities': [
        for (final a in amenityIds) {'id': a, 'name': 'A$a'}
      ],
      'reviews': [
        if (rating > 0) {'id': 1, 'rating': rating.round(), 'reviewer': {'name': 'X'}}
      ],
    });

void main() {
  group('VenueFilters counting', () {
    test('nothing set is empty', () {
      expect(VenueFilters.none.isEmpty, isTrue);
      expect(VenueFilters.none.activeCount, 0);
    });

    test('the full price range does not count as a filter', () {
      const f = VenueFilters(minPrice: 0, maxPrice: 5000);
      expect(f.activeCount, 0);
    });

    test('a narrowed price range counts', () {
      const f = VenueFilters(minPrice: 200, maxPrice: 800);
      expect(f.activeCount, 1);
    });

    test('each dimension counts once', () {
      const f = VenueFilters(
        sportIds: {1, 2},
        minPrice: 100,
        maxPrice: 900,
        maxDistanceKm: 5,
        minRating: 4,
        amenityIds: {3},
        hasRoof: true,
      );
      expect(f.activeCount, 6);
    });
  });

  group('VenueFilters equality (it is a provider family key)', () {
    test('same values are equal', () {
      expect(const VenueFilters(sportIds: {1, 2}, minRating: 4),
          const VenueFilters(sportIds: {2, 1}, minRating: 4));
    });

    test('equal filters hash the same', () {
      expect(const VenueFilters(sportIds: {1, 2}).hashCode,
          const VenueFilters(sportIds: {2, 1}).hashCode);
    });

    test('different values are not equal', () {
      expect(const VenueFilters(minRating: 4) == const VenueFilters(minRating: 5),
          isFalse);
    });
  });

  group('copyWith can clear, not just set', () {
    test('passing null clears a nullable filter', () {
      const f = VenueFilters(maxDistanceKm: 5, minRating: 4, hasRoof: true);
      final cleared =
          f.copyWith(maxDistanceKm: null, minRating: null, hasRoof: null);
      expect(cleared.maxDistanceKm, isNull);
      expect(cleared.minRating, isNull);
      expect(cleared.hasRoof, isNull);
    });

    test('omitting a field leaves it alone', () {
      const f = VenueFilters(maxDistanceKm: 5, minRating: 4);
      final same = f.copyWith(minPrice: 100);
      expect(same.maxDistanceKm, 5);
      expect(same.minRating, 4);
    });
  });

  group('apply() filters the list', () {
    test('price range excludes what falls outside', () {
      final list = [ground(id: 1, price: 100), ground(id: 2, price: 900)];
      const f = VenueFilters(minPrice: 0, maxPrice: 500);
      expect(f.apply(list).map((g) => g.id), [1]);
    });

    test('a ground with no price is kept rather than silently dropped', () {
      final unpriced = GroundModel.fromJson(
          {'id': 9, 'name': 'New', 'price_per_slot': '0', 'groundSports': []});
      const f = VenueFilters(minPrice: 100, maxPrice: 200);
      expect(f.apply([unpriced]).map((g) => g.id), [9]);
    });

    test('rating filters below the minimum', () {
      final list = [ground(id: 1, rating: 5), ground(id: 2, rating: 3)];
      const f = VenueFilters(minRating: 4);
      expect(f.apply(list).map((g) => g.id), [1]);
    });

    test('amenities require ALL of them, not any', () {
      final list = [
        ground(id: 1, amenityIds: [1, 2, 3]),
        ground(id: 2, amenityIds: [1]),
      ];
      const f = VenueFilters(amenityIds: {1, 2});
      expect(f.apply(list).map((g) => g.id), [1]);
    });

    test('no filters keeps everything', () {
      final list = [ground(id: 1, price: 10), ground(id: 2, price: 4000)];
      expect(VenueFilters.none.apply(list).length, 2);
    });
  });

  group('GroundModel reads the new fields', () {
    test('locality prefers area and city', () {
      expect(ground(area: 'Adambakkam', city: 'Chennai').locality,
          'Adambakkam · Chennai');
    });

    test('falls back to whichever half exists', () {
      expect(ground(city: 'Chennai').locality, 'Chennai');
      expect(ground(area: 'Mylapore').locality, 'Mylapore');
    });

    test('falls back to the address when there is no area', () {
      expect(ground(address: '5 MG Road').locality, '5 MG Road');
    });

    test('null when nothing is known, rather than a dash', () {
      expect(ground().locality, isNull);
    });

    test('reads the roof flag', () {
      expect(ground(hasRoof: true).hasRoof, isTrue);
      expect(ground().hasRoof, isFalse);
    });

    test('distance formats to one decimal nearby and whole km far away', () {
      expect(ground(distanceKm: 5.24).formattedDistance, '5.2 km');
      expect(ground(distanceKm: 12.7).formattedDistance, '13 km');
      expect(ground().formattedDistance, isNull);
    });

    test('slots left reads as a fraction of today', () {
      expect(ground(left: 4, total: 14).slotsLeftLabel, '4 of 14 slots left today');
    });

    test('an ungenerated day is unknown, not zero', () {
      expect(ground().slotsLeftLabel, isNull);
      expect(ground().isFullyBookedToday, isFalse);
    });

    test('zero left today is full', () {
      expect(ground(left: 0, total: 14).isFullyBookedToday, isTrue);
    });
  });
}
