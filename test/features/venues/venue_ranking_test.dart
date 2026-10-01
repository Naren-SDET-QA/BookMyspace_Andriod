import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/domain/venue_ranking.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Venue _v(
  String id, {
  String city = '',
  String state = '',
  String address = '',
  double rating = 0,
  int count = 0,
}) => Venue(
  id: id,
  name: id,
  latitude: 0,
  longitude: 0,
  city: city,
  state: state,
  address: address,
  avgRating: rating,
  ratingCount: count,
);

void main() {
  const location = RankingLocation(
    area: 'Madhapur',
    city: 'Hyderabad',
    district: 'Rangareddy',
    state: 'Telangana',
  );

  test('recommended score is avgRating * (ratingCount + 1)', () {
    expect(VenueRanking.recommendedScore(_v('a', rating: 4, count: 9)), 40);
    expect(VenueRanking.recommendedScore(_v('b', rating: 5)), 5);
  });

  test('tiers: area, city, district, state, other', () {
    expect(
      VenueRanking.tierOf(
        _v('a', city: 'Hyderabad', address: '12 Road, Madhapur'),
        location,
      ),
      VenueLocationTier.area,
    );
    expect(
      VenueRanking.tierOf(_v('b', city: 'hyderabad'), location),
      VenueLocationTier.city,
    );
    expect(
      VenueRanking.tierOf(
        _v('c', city: 'Shamshabad', address: 'Rangareddy dist'),
        location,
      ),
      VenueLocationTier.district,
    );
    expect(
      VenueRanking.tierOf(
        _v('d', city: 'Warangal', state: 'Telangana'),
        location,
      ),
      VenueLocationTier.state,
    );
    expect(
      VenueRanking.tierOf(_v('e', city: 'Pune', state: 'MH'), location),
      VenueLocationTier.other,
    );
  });

  test('rankByLocation orders by tier then recommended score', () {
    final ranked = VenueRanking.rankByLocation([
      _v('other', city: 'Pune', rating: 5, count: 1000),
      _v('state', city: 'Warangal', state: 'Telangana', rating: 5, count: 50),
      _v('city-low', city: 'Hyderabad', rating: 3, count: 1),
      _v('city-high', city: 'Hyderabad', rating: 4.5, count: 20),
      _v('area', city: 'Hyderabad', address: 'Madhapur', rating: 1),
    ], location);
    expect(ranked.map((v) => v.id), [
      'area',
      'city-high',
      'city-low',
      'state',
      'other',
    ]);
  });

  test('empty location falls back to recommended score (stable ties)', () {
    final ranked = VenueRanking.rankByRecommended([
      _v('a', rating: 4, count: 1),
      _v('b', rating: 4, count: 10),
      _v('c', rating: 4, count: 1),
    ]);
    expect(ranked.map((v) => v.id), ['b', 'a', 'c']);
  });

  test('merge keeps the first non-empty value per level', () {
    final merged = RankingLocation.merge(const [
      RankingLocation(city: 'Pune'),
      RankingLocation(area: 'Madhapur', city: 'Hyderabad', state: 'TS'),
    ]);
    expect(merged.city, 'Pune');
    expect(merged.area, 'Madhapur');
    expect(merged.state, 'TS');
  });

  group('rankSearchResults', () {
    final venues = [
      _v('pune', city: 'Pune', rating: 5, count: 100),
      _v('hyd', city: 'Hyderabad', rating: 3, count: 1),
    ];

    test('re-ranks relevance / distance without coordinates', () {
      for (final sort in [VenueSortBy.relevance, VenueSortBy.distance]) {
        final out = rankSearchResults(
          venues,
          VenueSearchQuery(sortBy: sort),
          location,
        );
        expect(out.first.id, 'hyd', reason: sort.name);
      }
    });

    test('keeps server order for explicit sorts or coordinates', () {
      expect(
        rankSearchResults(
          venues,
          const VenueSearchQuery(sortBy: VenueSortBy.priceAsc),
          location,
        ).first.id,
        'pune',
      );
      expect(
        rankSearchResults(
          venues,
          const VenueSearchQuery(latitude: 1, longitude: 1),
          location,
        ).first.id,
        'pune',
      );
    });

    test('query location overrides the selected location', () {
      final out = rankSearchResults(
        venues,
        const VenueSearchQuery(city: 'Pune'),
        location,
      );
      expect(out.first.id, 'pune');
    });
  });
}
