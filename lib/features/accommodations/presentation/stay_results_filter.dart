import '../../venues/domain/venue.dart';

/// Sort choices on the stay results page.
///
/// Price and guest-rating sorts are also sent to venue search. Star-class
/// order is applied to the loaded page because venue search has no star sort.
enum StaySort {
  topPicks,
  priceLow,
  priceHigh,
  starsHigh,
  starsLow,
  topReviewed;

  String get label => switch (this) {
    StaySort.topPicks => 'Our top picks',
    StaySort.priceLow => 'Price (lowest first)',
    StaySort.priceHigh => 'Price (highest first)',
    StaySort.starsHigh => 'Property rating (high to low)',
    StaySort.starsLow => 'Property rating (low to high)',
    StaySort.topReviewed => 'Top reviewed',
  };

  VenueSortBy get serverSort => switch (this) {
    StaySort.priceLow => VenueSortBy.priceAsc,
    StaySort.priceHigh => VenueSortBy.priceDesc,
    StaySort.topReviewed => VenueSortBy.rating,
    StaySort.topPicks ||
    StaySort.starsHigh ||
    StaySort.starsLow => VenueSortBy.relevance,
  };
}

/// Guest-rating words for a 1–5 average. Thresholds stay on that scale.
abstract final class StayReviewCopy {
  static const thresholds = <(double, String)>[
    (4.5, 'Wonderful: 4.5+'),
    (4.0, 'Very good: 4+'),
    (3.5, 'Good: 3.5+'),
    (3.0, 'Pleasant: 3+'),
  ];

  static String adjective(double rating) {
    if (rating >= 4.5) return 'Wonderful';
    if (rating >= 4.0) return 'Very good';
    if (rating >= 3.5) return 'Good';
    if (rating >= 3.0) return 'Pleasant';
    if (rating > 0) return 'Review score';
    return '';
  }
}

/// Which facet is relaxed when counting the other options in that group.
enum StayFacet { propertyType, facility, stars, rating, distance }

/// Filters for hotel and PG results.
///
/// Property type, facilities, star class, distance, and the popular toggles
/// are applied on the loaded page. Price and guest rating are also sent to
/// venue search so they are not limited to the first page.
class StayResultsFilter {
  const StayResultsFilter({
    this.propertyTypes = const {},
    this.facilities = const {},
    this.starClasses = const {},
    this.freeCancellation = false,
    this.breakfast = false,
    this.parking = false,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.maxDistanceKm,
  });

  /// Hotel keys: hotel, lodge, resort. PG keys: gents, ladies, coliving.
  final Set<String> propertyTypes;

  /// Facility names in lower case. A property must have every selected one.
  final Set<String> facilities;

  /// Exact hotel class, 1–5. `0` means unrated. Empty means any class.
  final Set<int> starClasses;
  final bool freeCancellation;
  final bool breakfast;
  final bool parking;
  final double? minPrice;
  final double? maxPrice;

  /// Minimum guest rating on the 1–5 scale.
  final double? minRating;

  /// Maximum distance from the search centre, in kilometres.
  final double? maxDistanceKm;

  static const hotelPropertyTypes = <(String, String)>[
    ('hotel', 'Hotels'),
    ('lodge', 'Lodges'),
    ('resort', 'Resorts'),
  ];

  static const pgPropertyTypes = <(String, String)>[
    ('gents', 'Gents'),
    ('ladies', 'Ladies'),
    ('coliving', 'Co-living'),
  ];

  int get activeCount {
    var count = propertyTypes.length + facilities.length + starClasses.length;
    if (freeCancellation) count++;
    if (breakfast) count++;
    if (parking) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minRating != null) count++;
    if (maxDistanceKm != null) count++;
    return count;
  }

  /// Lowest selected hotel class sent to venue search.
  ///
  /// Unrated-only selection stays client-side: a minimum star would hide it.
  int? get serverMinStar {
    final rated = starClasses.where((star) => star >= 1 && star <= 5);
    if (rated.isEmpty) return null;
    return rated.reduce((a, b) => a < b ? a : b);
  }

  StayResultsFilter copyWith({
    Set<String>? propertyTypes,
    Set<String>? facilities,
    Set<int>? starClasses,
    bool? freeCancellation,
    bool? breakfast,
    bool? parking,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    double? Function()? minRating,
    double? Function()? maxDistanceKm,
  }) {
    return StayResultsFilter(
      propertyTypes: propertyTypes ?? this.propertyTypes,
      facilities: facilities ?? this.facilities,
      starClasses: starClasses ?? this.starClasses,
      freeCancellation: freeCancellation ?? this.freeCancellation,
      breakfast: breakfast ?? this.breakfast,
      parking: parking ?? this.parking,
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      minRating: minRating != null ? minRating() : this.minRating,
      maxDistanceKm: maxDistanceKm != null
          ? maxDistanceKm()
          : this.maxDistanceKm,
    );
  }

  StayResultsFilter without(StayFacet facet) {
    return switch (facet) {
      StayFacet.propertyType => copyWith(propertyTypes: const {}),
      StayFacet.facility => copyWith(facilities: const {}),
      StayFacet.stars => copyWith(starClasses: const {}),
      StayFacet.rating => copyWith(minRating: () => null),
      StayFacet.distance => copyWith(maxDistanceKm: () => null),
    };
  }
}

/// Pure matching, counting, and ordering for stay results.
abstract final class StayResultsFilterEngine {
  static List<(String, String)> propertyOptions({required bool isPg}) {
    return isPg
        ? StayResultsFilter.pgPropertyTypes
        : StayResultsFilter.hotelPropertyTypes;
  }

  static double priceCeiling(List<Venue> venues) {
    var observed = 0.0;
    for (final venue in venues) {
      if (venue.price > observed) observed = venue.price;
    }
    if (observed <= 0) return 0;
    return (observed / 500).ceil() * 500;
  }

  static List<Venue> apply(
    List<Venue> venues,
    StayResultsFilter filter, {
    required bool isPg,
  }) {
    return venues
        .where((venue) => matches(venue, filter, isPg: isPg))
        .toList(growable: false);
  }

  static int count(
    List<Venue> venues,
    StayResultsFilter filter, {
    required bool isPg,
  }) {
    var total = 0;
    for (final venue in venues) {
      if (matches(venue, filter, isPg: isPg)) total++;
    }
    return total;
  }

  static bool matches(
    Venue venue,
    StayResultsFilter filter, {
    required bool isPg,
  }) {
    if (filter.propertyTypes.isNotEmpty &&
        !filter.propertyTypes.any((key) => matchesProperty(venue, key))) {
      return false;
    }
    if (filter.facilities.isNotEmpty) {
      final available = venue.facilities
          .where((item) => item.isAvailable)
          .map((item) => item.facility.trim().toLowerCase())
          .toSet();
      for (final facility in filter.facilities) {
        if (!available.contains(facility)) return false;
      }
    }
    if (!isPg &&
        filter.starClasses.isNotEmpty &&
        !_matchesStars(venue, filter.starClasses)) {
      return false;
    }
    if (filter.freeCancellation && !hasFreeCancellation(venue)) return false;
    if (filter.breakfast && !hasBreakfast(venue)) return false;
    if (filter.parking && !hasParking(venue)) return false;
    if (filter.minPrice != null || filter.maxPrice != null) {
      if (venue.price <= 0) return false;
      if (filter.minPrice != null && venue.price < filter.minPrice!) {
        return false;
      }
      if (filter.maxPrice != null && venue.price > filter.maxPrice!) {
        return false;
      }
    }
    if (filter.minRating != null && venue.avgRating < filter.minRating!) {
      return false;
    }
    if (filter.maxDistanceKm != null) {
      final distance = venue.distanceKm;
      if (distance == null || distance > filter.maxDistanceKm!) return false;
    }
    return true;
  }

  static bool matchesProperty(Venue venue, String key) {
    final haystack = [
      venue.category?.slug,
      venue.category?.name,
      venue.name,
      venue.description,
      venue.facilities.map((item) => item.facility).join(' '),
    ].whereType<String>().join(' ').toLowerCase();
    return switch (key) {
      'hotel' => haystack.contains('hotel') || haystack.contains('stay'),
      'lodge' => haystack.contains('lodge') || haystack.contains('guest house'),
      'resort' => haystack.contains('resort') || haystack.contains('homestay'),
      'gents' => RegExp(r'gent|(?<!wo)men|(?<!fe)male').hasMatch(haystack),
      'ladies' =>
        haystack.contains('ladies') ||
            haystack.contains('lady') ||
            haystack.contains('women') ||
            haystack.contains('female'),
      'coliving' =>
        haystack.contains('coliv') ||
            haystack.contains('co-liv') ||
            haystack.contains('unisex'),
      _ => false,
    };
  }

  static bool hasFreeCancellation(Venue venue) {
    final summary = venue.cancellationSummary.toLowerCase();
    if (summary.isEmpty) return false;
    if (summary.contains('non-refund') ||
        summary.contains('nonrefund') ||
        summary.contains('no refund')) {
      return false;
    }
    return summary.contains('free cancellation') ||
        (summary.contains('free') && summary.contains('cancel'));
  }

  static bool hasBreakfast(Venue venue) {
    if (venue.foodOptions.toLowerCase().contains('breakfast')) return true;
    return venue.facilities.any(
      (item) =>
          item.isAvailable && item.facility.toLowerCase().contains('breakfast'),
    );
  }

  static bool hasParking(Venue venue) {
    if (venue.parkingCapacity > 0) return true;
    return venue.facilities.any(
      (item) =>
          item.isAvailable && item.facility.toLowerCase().contains('parking'),
    );
  }

  static Map<String, String> facilityLabels(List<Venue> venues) {
    final labels = <String, String>{};
    for (final venue in venues) {
      for (final item in venue.facilities) {
        if (!item.isAvailable) continue;
        final label = item.facility.trim();
        if (label.isEmpty) continue;
        labels.putIfAbsent(label.toLowerCase(), () => label);
      }
    }
    return labels;
  }

  static List<Venue> sort(List<Venue> venues, StaySort sort) {
    if (sort == StaySort.topPicks || sort == StaySort.topReviewed) {
      return venues;
    }
    final copy = [...venues];
    switch (sort) {
      case StaySort.priceLow:
        copy.sort((a, b) => _comparePrice(a, b, ascending: true));
      case StaySort.priceHigh:
        copy.sort((a, b) => _comparePrice(a, b, ascending: false));
      case StaySort.starsHigh:
        copy.sort((a, b) => (b.starRating ?? -1).compareTo(a.starRating ?? -1));
      case StaySort.starsLow:
        copy.sort((a, b) => (a.starRating ?? 99).compareTo(b.starRating ?? 99));
      case StaySort.topPicks:
      case StaySort.topReviewed:
        break;
    }
    return copy;
  }

  static bool _matchesStars(Venue venue, Set<int> classes) {
    final stars = venue.starRating;
    if (stars == null || stars < 1 || stars > 5) return classes.contains(0);
    return classes.contains(stars);
  }

  static int _comparePrice(Venue a, Venue b, {required bool ascending}) {
    final aMissing = a.price <= 0;
    final bMissing = b.price <= 0;
    if (aMissing && bMissing) return 0;
    if (aMissing) return 1;
    if (bMissing) return -1;
    final order = a.price.compareTo(b.price);
    return ascending ? order : -order;
  }
}
