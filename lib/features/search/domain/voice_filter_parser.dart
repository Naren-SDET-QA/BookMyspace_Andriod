import '../../venues/domain/venue.dart';

/// Visual badge representation of a parsed voice filter attribute.
class VoiceFilterBadge {
  const VoiceFilterBadge({
    required this.iconEmoji,
    required this.title,
    required this.value,
  });

  final String iconEmoji;
  final String title;
  final String value;
}

/// Structured filter payload extracted from natural speech voice commands.
class VoiceFilterResult {
  const VoiceFilterResult({
    required this.rawSpokenText,
    this.cleanedSearchQuery = '',
    this.categorySlug,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.sortBy = VenueSortBy.relevance,
    this.isClearCommand = false,
    this.spokenFeedback = '',
    this.badges = const [],
  });

  final String rawSpokenText;
  final String cleanedSearchQuery;
  final String? categorySlug;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final VenueSortBy sortBy;
  final bool isClearCommand;
  final String spokenFeedback;
  final List<VoiceFilterBadge> badges;

  VenueSearchQuery toVenueSearchQuery() {
    if (isClearCommand) {
      return const VenueSearchQuery();
    }
    return VenueSearchQuery(
      query: cleanedSearchQuery,
      categorySlug: categorySlug,
      city: city,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sortBy: sortBy,
    );
  }
}

/// Comprehensive Natural Language Processing (NLP) Parser for BookMySpace Voice Commands.
/// Translates spoken voice requests into concrete VenueSearchQuery parameters.
class VoiceCommandFilterParser {
  static VoiceFilterResult parse(String spokenText) {
    final raw = spokenText.trim();
    final lower = raw.toLowerCase();

    if (raw.isEmpty) {
      return const VoiceFilterResult(rawSpokenText: '');
    }

    // 1. Reset / Clear Filters intent
    if (_isResetQuery(lower)) {
      return VoiceFilterResult(
        rawSpokenText: raw,
        cleanedSearchQuery: '',
        isClearCommand: true,
        spokenFeedback: 'Cleared all filters. Showing all verified spaces.',
        badges: const [
          VoiceFilterBadge(iconEmoji: '🔄', title: 'Filter', value: 'Reset All')
        ],
      );
    }

    String? categorySlug;
    String? detectedCity;
    double? minPrice;
    double? maxPrice;
    VenueSortBy sortBy = VenueSortBy.relevance;
    final badges = <VoiceFilterBadge>[];

    // 2. Category Detection
    if (_containsAny(
        lower, ['badminton', 'shuttle', 'wooden court', 'synthetic court'])) {
      categorySlug = 'sports_arena';
      badges.add(const VoiceFilterBadge(
          iconEmoji: '🏸', title: 'Category', value: 'Badminton'));
    } else if (_containsAny(
        lower, ['box cricket', 'cricket', 'pitch', 'nets'])) {
      categorySlug = 'sports_arena';
      badges.add(const VoiceFilterBadge(
          iconEmoji: '🏏', title: 'Category', value: 'Cricket'));
    } else if (_containsAny(lower, ['football', 'turf', 'soccer', 'futsal'])) {
      categorySlug = 'sports_arena';
      badges.add(const VoiceFilterBadge(
          iconEmoji: '⚽', title: 'Category', value: 'Football Turf'));
    } else if (_containsAny(lower,
        ['marriage hall', 'wedding hall', 'kalyana mandapam', 'shadi mahal'])) {
      categorySlug = 'function_halls';
      badges.add(const VoiceFilterBadge(
          iconEmoji: '💍', title: 'Category', value: 'Marriage Hall'));
    } else if (_containsAny(lower, [
      'function hall',
      'banquet',
      'convention',
      'party hall',
      'reception'
    ])) {
      categorySlug = 'function_halls';
      badges.add(const VoiceFilterBadge(
          iconEmoji: '🏛️', title: 'Category', value: 'Function Hall'));
    } else if (_containsAny(lower, [
      'pg',
      'hostel',
      'paying guest',
      'coliving',
      'co-living',
      'gents pg',
      'ladies pg'
    ])) {
      categorySlug = 'pg_hostels';
      final isGents = _containsAny(lower, ['gents', 'men', 'boys', 'male']);
      final isLadies =
          _containsAny(lower, ['ladies', 'women', 'girls', 'female']);
      if (isGents) {
        badges.add(const VoiceFilterBadge(
            iconEmoji: '👨', title: 'Gender', value: 'Gents PG'));
      } else if (isLadies) {
        badges.add(const VoiceFilterBadge(
            iconEmoji: '👩', title: 'Gender', value: 'Ladies PG'));
      } else {
        badges.add(const VoiceFilterBadge(
            iconEmoji: '🏠', title: 'Category', value: 'PG & Hostel'));
      }
    } else if (_containsAny(lower,
        ['hotel', 'lodge', 'resort', 'guest house', 'stay', 'room', 'rooms'])) {
      categorySlug = 'lodge_rooms';
      badges.add(const VoiceFilterBadge(
          iconEmoji: '🏨', title: 'Category', value: 'Lodge / Rooms'));
    } else if (_containsAny(lower, [
      'coaching',
      'tuition',
      'classes',
      'dance class',
      'music class',
      'institute',
      'academy'
    ])) {
      categorySlug = 'institutes_classes';
      badges.add(const VoiceFilterBadge(
          iconEmoji: '🎓', title: 'Category', value: 'Institutes / Classes'));
    }

    // 3. Location / City Detection
    final cityMatches = {
      'hyderabad': 'Hyderabad',
      'hitec city': 'Hyderabad',
      'gachibowli': 'Hyderabad',
      'madhapur': 'Hyderabad',
      'kondapur': 'Hyderabad',
      'jubilee hills': 'Hyderabad',
      'banjara hills': 'Hyderabad',
      'kukatpally': 'Hyderabad',
      'secunderabad': 'Hyderabad',
      'bangalore': 'Bangalore',
      'bengaluru': 'Bangalore',
      'mumbai': 'Mumbai',
      'delhi': 'Delhi',
      'chennai': 'Chennai',
      'pune': 'Pune',
      'kolkata': 'Kolkata',
    };

    for (final entry in cityMatches.entries) {
      if (lower.contains(entry.key)) {
        detectedCity = entry.value;
        badges.add(VoiceFilterBadge(
          iconEmoji: '📍',
          title: 'Location',
          value: entry.key.toUpperCase() == entry.value.toUpperCase()
              ? entry.value
              : '${entry.key[0].toUpperCase()}${entry.key.substring(1)}, ${entry.value}',
        ));
        break;
      }
    }

    // 4. Price Detection (e.g. "under 2000", "below 50k", "less than 50,000", "above 1000")
    final maxPriceRegex = RegExp(
        r'(?:under|below|less than|max|within|budget of?)\s*(?:rs\.?|inr|₹)?\s*(\d+[\d,]*\s*k?)',
        caseSensitive: false);
    final maxMatch = maxPriceRegex.firstMatch(lower);
    if (maxMatch != null) {
      final parsed = _parsePriceString(maxMatch.group(1));
      if (parsed != null && parsed > 0) {
        maxPrice = parsed;
        badges.add(VoiceFilterBadge(
          iconEmoji: '💰',
          title: 'Max Price',
          value: '₹${parsed.toInt()}',
        ));
      }
    }

    final minPriceRegex = RegExp(
        r'(?:above|more than|min|at least|starting from?)\s*(?:rs\.?|inr|₹)?\s*(\d+[\d,]*\s*k?)',
        caseSensitive: false);
    final minMatch = minPriceRegex.firstMatch(lower);
    if (minMatch != null) {
      final parsed = _parsePriceString(minMatch.group(1));
      if (parsed != null && parsed > 0) {
        minPrice = parsed;
        badges.add(VoiceFilterBadge(
          iconEmoji: '💵',
          title: 'Min Price',
          value: '₹${parsed.toInt()}',
        ));
      }
    }

    // 5. Sort By Detection
    if (_containsAny(
        lower, ['cheapest', 'low price', 'lowest price', 'affordable'])) {
      sortBy = VenueSortBy.priceAsc;
      badges.add(const VoiceFilterBadge(
          iconEmoji: '🏷️', title: 'Sort', value: 'Price: Low to High'));
    } else if (_containsAny(
        lower, ['best rated', 'top rated', 'highest rating', 'popular'])) {
      sortBy = VenueSortBy.rating;
      badges.add(const VoiceFilterBadge(
          iconEmoji: '⭐', title: 'Sort', value: 'Top Rated'));
    }

    // 6. Clean Query Extraction
    var cleaned = raw;
    final stopWords = [
      'find me',
      'show me',
      'search for',
      'looking for',
      'i want',
      'i need',
      'book a',
      'book an',
      'near me',
      'around me',
      'available',
      'spaces',
      'venues',
      'halls',
      'places',
      'please',
      'can you',
      'in',
      'at',
      'near',
      'under',
      'below',
      'above',
      'more than',
      'less than',
      'budget of',
      'rs',
      'inr',
      'rupees',
      'k',
    ];

    var lowerCleaned = cleaned.toLowerCase();
    for (final sw in stopWords) {
      final pattern =
          RegExp(r'\b' + RegExp.escape(sw) + r'\b', caseSensitive: false);
      lowerCleaned = lowerCleaned.replaceAll(pattern, ' ');
    }

    // Also remove digits associated with price
    if (maxPrice != null) {
      lowerCleaned = lowerCleaned.replaceAll(RegExp(r'\b\d+k?\b'), ' ');
    }

    final words = lowerCleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().length > 2)
        .toList();

    cleaned = words.join(' ').trim();

    return VoiceFilterResult(
      rawSpokenText: raw,
      cleanedSearchQuery: cleaned,
      categorySlug: categorySlug,
      city: detectedCity,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sortBy: sortBy,
      isClearCommand: false,
      spokenFeedback: 'Voice search active: ${_buildFeedback(badges)}',
      badges: badges,
    );
  }

  static bool _isResetQuery(String text) {
    return _containsAny(text, [
      'reset',
      'clear',
      'clear all',
      'remove filters',
      'clear filters',
      'show all',
      'view all',
      'start over',
      'clean'
    ]);
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }

  static double? _parsePriceString(String? text) {
    if (text == null) return null;
    var cleaned = text.trim().toLowerCase().replaceAll(',', '');
    var multiplier = 1.0;
    if (cleaned.endsWith('k')) {
      multiplier = 1000.0;
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    final num = double.tryParse(cleaned);
    if (num == null) return null;
    return num * multiplier;
  }

  static String _buildFeedback(List<VoiceFilterBadge> badges) {
    if (badges.isEmpty) return 'Found results for your search';
    return badges.map((b) => '${b.title}: ${b.value}').join(', ');
  }
}
