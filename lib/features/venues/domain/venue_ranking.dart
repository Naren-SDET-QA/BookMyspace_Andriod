import 'venue.dart';

/// The user's selected location hierarchy used to rank venues when no
/// coordinates are available (reference: SearchScreen.kt RELEVANCE sort and
/// HomeScreen.kt DISTANCE / RECOMMENDED sorts).
class RankingLocation {
  const RankingLocation({this.area, this.city, this.district, this.state});

  final String? area;
  final String? city;
  final String? district;
  final String? state;

  bool get isEmpty =>
      _norm(area).isEmpty &&
      _norm(city).isEmpty &&
      _norm(district).isEmpty &&
      _norm(state).isEmpty;

  /// First non-empty value wins per level, so callers can layer an explicit
  /// query over the discovery location over the search area.
  static RankingLocation merge(Iterable<RankingLocation> sources) {
    String? pick(String? Function(RankingLocation l) read) {
      for (final source in sources) {
        final value = read(source);
        if (_norm(value).isNotEmpty) return value!.trim();
      }
      return null;
    }

    return RankingLocation(
      area: pick((l) => l.area),
      city: pick((l) => l.city),
      district: pick((l) => l.district),
      state: pick((l) => l.state),
    );
  }
}

/// Location tier of a venue relative to the user's selection.
///
/// 0 = same area/locality, 1 = same city, 2 = same district,
/// 3 = same state, 4 = anything else.
enum VenueLocationTier { area, city, district, state, other }

/// Pure client-side ranking helpers; no I/O.
abstract final class VenueRanking {
  /// "Recommended" score: `avgRating * (ratingCount + 1)`.
  static double recommendedScore(Venue venue) =>
      venue.avgRating * (venue.ratingCount + 1);

  static VenueLocationTier tierOf(Venue venue, RankingLocation location) {
    final area = _norm(location.area);
    final city = _norm(location.city);
    final district = _norm(location.district);
    final state = _norm(location.state);
    final venueCity = _norm(venue.city);
    final venueState = _norm(venue.state);
    final address = _norm(venue.address);

    // Venues have no dedicated area column: the locality lives in the
    // address (or occasionally in the city field for small towns).
    if (area.isNotEmpty &&
        (_containsWord(address, area) || venueCity == area)) {
      return VenueLocationTier.area;
    }
    if (city.isNotEmpty && venueCity == city) return VenueLocationTier.city;
    if (district.isNotEmpty &&
        (venueCity == district || _containsWord(address, district))) {
      return VenueLocationTier.district;
    }
    if (state.isNotEmpty && venueState == state) {
      return VenueLocationTier.state;
    }
    return VenueLocationTier.other;
  }

  /// Orders [venues] by location tier (area → city → district → state →
  /// others), then by [recommendedScore] descending. Stable for ties.
  static List<Venue> rankByLocation(
    List<Venue> venues,
    RankingLocation location,
  ) {
    final indexed = venues.indexed.toList();
    indexed.sort((a, b) {
      final tier = tierOf(
        a.$2,
        location,
      ).index.compareTo(tierOf(b.$2, location).index);
      if (tier != 0) return tier;
      final score = recommendedScore(b.$2).compareTo(recommendedScore(a.$2));
      if (score != 0) return score;
      return a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }

  /// Orders [venues] by [recommendedScore] descending. Stable for ties.
  static List<Venue> rankByRecommended(List<Venue> venues) =>
      rankByLocation(venues, const RankingLocation());
}

String _norm(String? value) => (value ?? '').trim().toLowerCase();

bool _containsWord(String haystack, String needle) {
  if (haystack.isEmpty || needle.isEmpty) return false;
  return RegExp(
    r'(^|[^a-z0-9])' + RegExp.escape(needle) + r'($|[^a-z0-9])',
  ).hasMatch(haystack);
}
