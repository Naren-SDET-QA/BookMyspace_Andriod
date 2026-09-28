import 'package:bookmyspace/core/router/search_route.dart';
import 'package:bookmyspace/features/search/domain/voice_filter_parser.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

VoiceFilterResult _p(String text) => VoiceCommandFilterParser.parse(text);

void main() {
  group('backward compatible output', () {
    test('category, city and max price', () {
      final r = _p('badminton courts in Hyderabad under 1000');
      expect(r.categorySlug, 'sports_arena');
      expect(r.city, 'Hyderabad');
      expect(r.maxPrice, 1000);
      expect(r.minPrice, isNull);
      expect(r.minRating, isNull);
      expect(r.minCapacity, isNull);
      expect(r.amenities, isEmpty);
      expect(r.sortBy, VenueSortBy.relevance);
    });

    test('50k budgets and cheapest sort', () {
      final r = _p('cheapest marriage hall in Gachibowli under 50k');
      expect(r.maxPrice, 50000);
      expect(r.sortBy, VenueSortBy.priceAsc);
      expect(r.categorySlug, 'function_halls');
    });

    test('min price above a real amount stays a price', () {
      final r = _p('function hall above 20000');
      expect(r.minPrice, 20000);
      expect(r.minRating, isNull);
    });

    test('clear command resets everything', () {
      final r = _p('clear filters');
      expect(r.isClearCommand, isTrue);
      expect(r.toVenueSearchQuery().hasFilters, isFalse);
    });
  });

  group('PG gender and sharing', () {
    test('gents / boys / male', () {
      for (final text in ['gents pg', 'boys hostel', 'pg for male']) {
        expect(_p(text).pgGender, 'gents', reason: text);
        expect(_p(text).categorySlug, 'pg_hostels', reason: text);
      }
    });

    test('ladies / girls / women (never misread as men)', () {
      for (final text in ['ladies pg', 'girls hostel', 'pg for women']) {
        expect(_p(text).pgGender, 'ladies', reason: text);
      }
    });

    test('coliving', () {
      final r = _p('coliving space in madhapur');
      expect(r.pgGender, 'coliving');
      expect(r.badges.map((b) => b.value), contains('Co-Living'));
    });

    test('sharing types', () {
      expect(_p('single room pg').sharing, 'single');
      expect(_p('double sharing hostel').sharing, 'double');
      expect(_p('pg with 3 sharing').sharing, 'triple');
      expect(_p('four sharing pg').sharing, '4 sharing');
      // "2 sharing" alone implies a PG.
      expect(_p('2 sharing in kondapur').categorySlug, 'pg_hostels');
    });
  });

  group('rating', () {
    test('top rated means 4.0+ and rating sort', () {
      final r = _p('top rated banquet');
      expect(r.minRating, 4.0);
      expect(r.sortBy, VenueSortBy.rating);
    });

    test('above 4 is a rating, not a price', () {
      final r = _p('function hall above 4');
      expect(r.minRating, 4.0);
      expect(r.minPrice, isNull);
    });

    test('4 star and above / 4.5+ stars / rated above 3.5', () {
      expect(_p('4 star and above halls').minRating, 4.0);
      expect(_p('turf 4.5+ stars').minRating, 4.5);
      expect(_p('rated above 3.5').minRating, 3.5);
    });

    test('hotel star class is skipped', () {
      expect(_p('4 star hotel').minRating, isNull);
    });
  });

  group('capacity', () {
    test('for 200 people is a minimum', () {
      final r = _p('banquet hall for 200 people');
      expect(r.minCapacity, 200);
      expect(r.maxCapacity, isNull);
      expect(r.cleanedSearchQuery, isNot(contains('200')));
      expect(r.cleanedSearchQuery, isNot(contains('people')));
    });

    test('above 100 guests is capacity, not price', () {
      final r = _p('hall above 100 guests');
      expect(r.minCapacity, 100);
      expect(r.minPrice, isNull);
    });

    test('up to 50 guests is a maximum', () {
      final r = _p('party hall up to 50 guests under 20000');
      expect(r.maxCapacity, 50);
      expect(r.maxPrice, 20000);
    });
  });

  group('amenities', () {
    test('maps spoken amenities to catalog ids', () {
      final r = _p(
        'function hall with ac parking wifi catering pool lawn '
        'power backup dj rooms and bar',
      );
      expect(
        r.amenities,
        containsAll([
          'ac',
          'parking',
          'wifi',
          'catering',
          'pool',
          'lawn',
          'power_backup',
          'stage_sound',
          'rooms',
          'alcohol',
        ]),
      );
      expect(r.cleanedSearchQuery, isNot(contains('parking')));
    });

    test('word boundaries: "space"/"academy" do not mean AC', () {
      expect(_p('event space in hyderabad').amenities, isEmpty);
    });

    test('PG food maps to the PG food amenity; lodge rooms is a category', () {
      expect(_p('ladies pg with food').amenities, contains('food'));
      expect(
        _p('lodge rooms in hyderabad').amenities,
        isNot(contains('rooms')),
      );
    });
  });

  group('sort', () {
    test('nearest / largest / most expensive', () {
      expect(_p('nearest turf').sortBy, VenueSortBy.distance);
      expect(_p('biggest banquet hall').sortBy, VenueSortBy.capacity);
      expect(_p('most expensive banquet').sortBy, VenueSortBy.priceDesc);
    });
  });

  test('toVenueSearchQuery carries the new filters and they round-trip '
      'through the search route', () {
    final r = _p('top rated ladies pg double sharing with wifi for 2 people');
    final q = r.toVenueSearchQuery();
    expect(q.gender, 'ladies');
    expect(q.sharing, 'double');
    expect(q.minRating, 4.0);
    expect(q.minCapacity, 2);
    expect(q.amenities, {'wifi'});

    final location = SearchRouteParams.locationFor(q);
    final back = SearchRouteParams.fromUri(Uri.parse(location)).toQuery();
    expect(back, q);
  });
}
