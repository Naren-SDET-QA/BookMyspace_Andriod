import 'package:bookmyspace/core/router/search_route.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchRouteParams', () {
    test('encodes category and query into the search location', () {
      const query = VenueSearchQuery(
        query: 'hall',
        categorySlug: 'meeting_room',
        sortBy: VenueSortBy.priceAsc,
      );
      expect(
        SearchRouteParams.locationFor(query),
        '/search?q=hall&category=meeting_room&sort=priceAsc',
      );
    });

    test('reads query parameters as the source of truth', () {
      final params = SearchRouteParams.fromUri(
        Uri.parse('/search?category=pg_hostels&q=hitech'),
        extra: {'category': 'should_be_ignored'},
      );
      expect(params.categorySlug, 'pg_hostels');
      expect(params.query, 'hitech');
    });

    test('empty query parameters clear compatibility extras', () {
      final params = SearchRouteParams.fromUri(
        Uri.parse('/search?category=&q='),
        extra: {'category': 'function_hall', 'q': 'stale'},
      );
      expect(params.categorySlug, isNull);
      expect(params.query, isEmpty);
    });

    test('falls back to extra when query parameters are absent', () {
      final params = SearchRouteParams.fromUri(
        Uri.parse('/search'),
        extra: {'category': 'function_hall', 'q': 'banquet'},
      );
      expect(params.categorySlug, 'function_hall');
      expect(params.query, 'banquet');
    });

    test('round-trips a full query including map venue id', () {
      final location = SearchRouteParams.mapLocationFor(
        const VenueSearchQuery(categorySlug: 'sports_turfs', query: 'box'),
        venueId: 'v9',
      );
      final parsed = SearchRouteParams.fromUri(Uri.parse(location));
      expect(parsed.categorySlug, 'sports_turfs');
      expect(parsed.query, 'box');
      expect(parsed.venueId, 'v9');
      expect(parsed.mapLocation, location);
    });

    test('round-trips GPS and PIN query parameters without dropping city', () {
      const query = VenueSearchQuery(
        city: 'Chennai',
        latitude: 13.0827,
        longitude: 80.2707,
        radiusKm: 10,
        pincode: '600001',
      );
      final location = SearchRouteParams.locationFor(query);
      expect(location, contains('city=Chennai'));
      expect(location, contains('pin=600001'));
      final parsed = SearchRouteParams.fromUri(Uri.parse(location)).toQuery();
      expect(parsed.city, 'Chennai');
      expect(parsed.latitude, 13.0827);
      expect(parsed.pincode, '600001');
    });

    test('round-trips every Home category through Search', () {
      const categorySlugs = [
        'function_halls',
        'lodge_rooms',
        'pg_hostels',
        'institutes_classes',
        'sports_turfs',
      ];

      for (final slug in categorySlugs) {
        final location = SearchRouteParams(categorySlug: slug).searchLocation;
        final parsed = SearchRouteParams.fromUri(Uri.parse(location));
        expect(parsed.categorySlug, slug);
      }
    });
  });
}
