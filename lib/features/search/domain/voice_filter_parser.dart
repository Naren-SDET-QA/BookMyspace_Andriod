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
    this.pgGender,
    this.sharing,
    this.minRating,
    this.minCapacity,
    this.maxCapacity,
    this.amenities = const {},
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

  /// PG gender type: `gents`, `ladies` or `coliving` (values understood by
  /// [VenueSearchQuery.gender]).
  final String? pgGender;

  /// PG sharing type: `single`, `double`, `triple` or `4 sharing`.
  final String? sharing;

  /// Minimum average rating (e.g. 4.0 for "top rated" / "above 4").
  final double? minRating;

  /// Minimum guests the space must hold ("for 200 people").
  final int? minCapacity;

  /// Maximum guests ("up to 100 guests").
  final int? maxCapacity;

  /// Canonical amenity ids (see `CustomerSectionCatalog.amenityFilters`).
  final Set<String> amenities;

  bool get isEducationIntent => categorySlug == 'institutes_classes';

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
      gender: pgGender,
      sharing: sharing,
      minRating: minRating,
      minCapacity: minCapacity,
      maxCapacity: maxCapacity,
      amenities: amenities,
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
          VoiceFilterBadge(
            iconEmoji: '🔄',
            title: 'Filter',
            value: 'Reset All',
          ),
        ],
      );
    }

    String? categorySlug;
    String? detectedCity;
    double? minPrice;
    double? maxPrice;
    VenueSortBy sortBy = VenueSortBy.relevance;
    String? pgGender;
    String? sharing;
    double? minRating;
    int? minCapacity;
    int? maxCapacity;
    final amenities = <String>{};
    final badges = <VoiceFilterBadge>[];
    // Spans consumed by capacity / rating phrases; blanked out before the
    // price regexes run ("above 100 guests" is not a price) and before the
    // free-text keyword is built.
    final consumed = <Match>[];

    // 2. Category Detection
    if (_containsAny(lower, [
      'coaching',
      'tuition',
      'classes',
      'dance class',
      'music class',
      'institute',
      'academy',
      'badminton training',
      'coding bootcamp',
      'bootcamp',
    ])) {
      categorySlug = 'institutes_classes';
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '🎓',
          title: 'Category',
          value: 'Institutes / Classes',
        ),
      );
    } else if (_containsAny(lower, [
      'badminton',
      'shuttle',
      'wooden court',
      'synthetic court',
    ])) {
      categorySlug = 'sports_arena';
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '🏸',
          title: 'Category',
          value: 'Badminton',
        ),
      );
    } else if (_containsAny(lower, [
      'box cricket',
      'cricket',
      'pitch',
      'nets',
    ])) {
      categorySlug = 'sports_arena';
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '🏏',
          title: 'Category',
          value: 'Cricket',
        ),
      );
    } else if (_containsAny(lower, ['football', 'turf', 'soccer', 'futsal'])) {
      categorySlug = 'sports_arena';
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '⚽',
          title: 'Category',
          value: 'Football Turf',
        ),
      );
    } else if (_containsAny(lower, [
      'marriage hall',
      'wedding hall',
      'kalyana mandapam',
      'shadi mahal',
    ])) {
      categorySlug = 'function_halls';
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '💍',
          title: 'Category',
          value: 'Marriage Hall',
        ),
      );
    } else if (_containsAny(lower, [
      'function hall',
      'banquet',
      'convention',
      'party hall',
      'reception',
    ])) {
      categorySlug = 'function_halls';
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '🏛️',
          title: 'Category',
          value: 'Function Hall',
        ),
      );
    } else if (_containsAny(lower, [
      'pg',
      'hostel',
      'paying guest',
      'coliving',
      'co-living',
      'gents pg',
      'ladies pg',
    ])) {
      categorySlug = 'pg_hostels';
      pgGender = _pgGenderFor(lower);
      if (pgGender == 'gents') {
        badges.add(
          const VoiceFilterBadge(
            iconEmoji: '👨',
            title: 'Gender',
            value: 'Gents PG',
          ),
        );
      } else if (pgGender == 'ladies') {
        badges.add(
          const VoiceFilterBadge(
            iconEmoji: '👩',
            title: 'Gender',
            value: 'Ladies PG',
          ),
        );
      } else {
        badges.add(
          const VoiceFilterBadge(
            iconEmoji: '🏠',
            title: 'Category',
            value: 'PG & Hostel',
          ),
        );
        if (pgGender == 'coliving') {
          badges.add(
            const VoiceFilterBadge(
              iconEmoji: '👥',
              title: 'Type',
              value: 'Co-Living',
            ),
          );
        }
      }
    } else if (_containsAny(lower, [
      'hotel',
      'lodge',
      'resort',
      'guest house',
      'stay',
      'room',
      'rooms',
    ])) {
      categorySlug = 'lodge_rooms';
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '🏨',
          title: 'Category',
          value: 'Lodge / Rooms',
        ),
      );
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
        badges.add(
          VoiceFilterBadge(
            iconEmoji: '📍',
            title: 'Location',
            value: entry.key.toUpperCase() == entry.value.toUpperCase()
                ? entry.value
                : '${entry.key[0].toUpperCase()}${entry.key.substring(1)}, ${entry.value}',
          ),
        );
        break;
      }
    }

    // 3b. PG sharing type
    if (categorySlug == 'pg_hostels' || lower.contains('sharing')) {
      final spec = _sharingFor(lower);
      if (spec != null) {
        sharing = spec.$1;
        categorySlug ??= 'pg_hostels';
        badges.add(
          VoiceFilterBadge(iconEmoji: '🛏️', title: 'Sharing', value: spec.$2),
        );
      }
    }

    // 3c. Capacity / guests ("for 200 people", "above 100 guests")
    final capacity = _extractCapacity(lower);
    if (capacity != null) {
      consumed.add(capacity.match);
      if (capacity.isMax) {
        maxCapacity = capacity.value;
        badges.add(
          VoiceFilterBadge(
            iconEmoji: '👥',
            title: 'Capacity',
            value: 'Up to ${capacity.value} Guests',
          ),
        );
      } else {
        minCapacity = capacity.value;
        badges.add(
          VoiceFilterBadge(
            iconEmoji: '👥',
            title: 'Capacity',
            value: '${capacity.value}+ Guests',
          ),
        );
      }
    }

    // 3d. Minimum rating ("top rated", "above 4", "4 star and above")
    final rating = _extractRating(lower);
    if (rating != null) {
      minRating = rating.value;
      if (rating.match != null) consumed.add(rating.match!);
      badges.add(
        VoiceFilterBadge(
          iconEmoji: '⭐',
          title: 'Rating',
          value: '${rating.value.toStringAsFixed(1)}+ ★',
        ),
      );
    }

    // 3e. Amenities
    for (final spec in _amenitySpecs) {
      if (spec.id == 'rooms' &&
          (categorySlug == 'lodge_rooms' || categorySlug == 'pg_hostels')) {
        // "rooms" names the category itself there, not an amenity.
        continue;
      }
      if (!spec.keywords.any((k) => _hasPhrase(lower, k))) continue;
      final id = spec.id == 'catering' && categorySlug == 'pg_hostels'
          ? 'food'
          : spec.id;
      if (amenities.add(id)) {
        badges.add(
          VoiceFilterBadge(
            iconEmoji: spec.emoji,
            title: 'Amenity',
            value: spec.label,
          ),
        );
      }
    }

    // Text the price regexes see: capacity/rating phrases removed.
    final priceText = _blank(lower, consumed);

    // 4. Price Detection (e.g. "under 2000", "below 50k", "less than 50,000", "above 1000")
    final maxPriceRegex = RegExp(
      r'(?:under|below|less than|max|within|budget of?)\s*(?:rs\.?|inr|₹)?\s*(\d+[\d,]*\s*k?)' +
          _notCapacityOrRating,
      caseSensitive: false,
    );
    final maxMatch = maxPriceRegex.firstMatch(priceText);
    if (maxMatch != null) {
      final parsed = _parsePriceString(maxMatch.group(1));
      if (parsed != null && parsed > 0) {
        maxPrice = parsed;
        badges.add(
          VoiceFilterBadge(
            iconEmoji: '💰',
            title: 'Max Price',
            value: '₹${parsed.toInt()}',
          ),
        );
      }
    }

    final minPriceRegex = RegExp(
      r'(?:above|more than|min|at least|starting from?)\s*(?:rs\.?|inr|₹)?\s*(\d+[\d,]*\s*k?)' +
          _notCapacityOrRating,
      caseSensitive: false,
    );
    final minMatch = minPriceRegex.firstMatch(priceText);
    if (minMatch != null) {
      final parsed = _parsePriceString(minMatch.group(1));
      if (parsed != null && parsed > 0) {
        minPrice = parsed;
        badges.add(
          VoiceFilterBadge(
            iconEmoji: '💵',
            title: 'Min Price',
            value: '₹${parsed.toInt()}',
          ),
        );
      }
    }

    // 5. Sort By Detection
    if (_containsAny(lower, [
      'cheapest',
      'low price',
      'lowest price',
      'affordable',
    ])) {
      sortBy = VenueSortBy.priceAsc;
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '🏷️',
          title: 'Sort',
          value: 'Price: Low to High',
        ),
      );
    } else if (_containsAny(lower, [
      'best rated',
      'top rated',
      'highest rating',
      'popular',
    ])) {
      sortBy = VenueSortBy.rating;
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '⭐',
          title: 'Sort',
          value: 'Top Rated',
        ),
      );
    } else if (_containsAny(lower, _priceDescWords)) {
      sortBy = VenueSortBy.priceDesc;
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '💎',
          title: 'Sort',
          value: 'Price: High to Low',
        ),
      );
    } else if (_containsAny(lower, _capacitySortWords)) {
      sortBy = VenueSortBy.capacity;
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '👑',
          title: 'Sort',
          value: 'Largest Capacity',
        ),
      );
    } else if (_containsAny(lower, _nearestWords)) {
      sortBy = VenueSortBy.distance;
      badges.add(
        const VoiceFilterBadge(
          iconEmoji: '📍',
          title: 'Sort',
          value: 'Nearest First',
        ),
      );
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

    var lowerCleaned = _blank(cleaned.toLowerCase(), consumed);
    final extraStopWords = <String>[
      if (sharing != null) ...[
        'single',
        'double',
        'triple',
        'sharing',
        'one',
        'two',
        'three',
        'four',
        'private room',
      ],
      if (minRating != null) ..._ratingWords,
      if (sortBy == VenueSortBy.priceDesc) ..._priceDescWords,
      if (sortBy == VenueSortBy.capacity) ..._capacitySortWords,
      if (sortBy == VenueSortBy.distance) ..._nearestWords,
      for (final spec in _amenitySpecs)
        if (amenities.contains(spec.id) ||
            (spec.id == 'catering' && amenities.contains('food')))
          ...spec.keywords,
      if (amenities.isNotEmpty) 'with',
    ]..sort((a, b) => b.length.compareTo(a.length));
    for (final sw in extraStopWords) {
      lowerCleaned = lowerCleaned.replaceAll(
        RegExp(
          r'(?<![a-z0-9])' + RegExp.escape(sw) + r'(?![a-z0-9])',
          caseSensitive: false,
        ),
        ' ',
      );
    }
    for (final sw in stopWords) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(sw) + r'\b',
        caseSensitive: false,
      );
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
      pgGender: pgGender,
      sharing: sharing,
      minRating: minRating,
      minCapacity: minCapacity,
      maxCapacity: maxCapacity,
      amenities: amenities,
    );
  }

  // --- Extended extraction (reference VoiceCommandFilterParser parity) ------

  /// Lookahead appended to price regexes so a number that is really a
  /// guest count or a star rating is never read as a price.
  static const String _notCapacityOrRating =
      r'(?![\d,])(?!\s*(?:people|persons|person|guests|guest|pax|members|seats|heads|star|stars|★|rating|rated))';

  static const _capacityUnits =
      r'(?:people|persons|person|guests|guest|pax|members|seats|heads)';

  static const _ratingWords = [
    'top rated',
    'best rated',
    'highest rated',
    'highest rating',
    'best rating',
    'best reviews',
    'star',
    'stars',
    'rating',
    'rated',
    'and above',
    'or above',
    'or more',
    'plus',
  ];

  static const _priceDescWords = [
    'most expensive',
    'price high to low',
    'highest price',
    'luxury',
    'premium',
    'high end',
  ];

  static const _capacitySortWords = [
    'biggest',
    'largest',
    'maximum capacity',
    'highest capacity',
    'most capacity',
    'sort by capacity',
  ];

  static const _nearestWords = [
    'nearest',
    'nearby',
    'closest',
    'near me',
    'around me',
    'sort by distance',
  ];

  static const List<_AmenitySpec> _amenitySpecs = [
    _AmenitySpec('ac', 'Air Conditioned', '❄️', [
      'ac',
      'a/c',
      'air condition',
      'air conditioned',
      'air conditioning',
      'central ac',
      'cooling',
    ]),
    _AmenitySpec('parking', 'Parking', '🚗', [
      'parking',
      'car parking',
      'valet',
      'garage',
    ]),
    _AmenitySpec('wifi', 'Wi-Fi', '📶', ['wifi', 'wi-fi', 'wi fi', 'internet']),
    _AmenitySpec('catering', 'Catering & Food', '🍽️', [
      'catering',
      'food',
      'buffet',
      'meals',
      'meal',
      'kitchen',
      'breakfast',
      'dinner',
    ]),
    _AmenitySpec('pool', 'Swimming Pool', '🏊', [
      'pool',
      'swimming pool',
      'swimming',
    ]),
    _AmenitySpec('lawn', 'Lawn / Garden', '🌿', [
      'lawn',
      'garden',
      'terrace',
      'open air',
    ]),
    _AmenitySpec('power_backup', 'Power Backup', '⚡', [
      'power backup',
      'generator',
      'backup',
    ]),
    _AmenitySpec('stage_sound', 'Stage & Audio', '🔊', [
      'stage',
      'sound system',
      'dj',
      'speakers',
      'audio',
      'mic',
    ]),
    _AmenitySpec('rooms', 'Guest Rooms', '🛏️', [
      'rooms',
      'guest room',
      'guest rooms',
      'bridal room',
      'changing room',
    ]),
    _AmenitySpec('alcohol', 'Bar / Drinks', '🍸', [
      'alcohol',
      'bar',
      'liquor',
      'drinks',
    ]),
  ];

  static String? _pgGenderFor(String lower) {
    if (_containsAnyPhrase(lower, [
      'ladies',
      'lady',
      'women',
      'girls',
      'girl',
      'female',
    ])) {
      return 'ladies';
    }
    if (_containsAnyPhrase(lower, [
      'gents',
      'gent',
      'men',
      'boys',
      'boy',
      'male',
    ])) {
      return 'gents';
    }
    if (_containsAnyPhrase(lower, [
      'coliving',
      'co-living',
      'co living',
      'unisex',
    ])) {
      return 'coliving';
    }
    return null;
  }

  static (String, String)? _sharingFor(String lower) {
    if (_containsAnyPhrase(lower, [
      'single',
      '1 sharing',
      'one sharing',
      'single sharing',
      'private room',
    ])) {
      return ('single', 'Single Room');
    }
    if (_containsAnyPhrase(lower, [
      'double',
      '2 sharing',
      'two sharing',
      'double sharing',
    ])) {
      return ('double', '2 Sharing');
    }
    if (_containsAnyPhrase(lower, [
      'triple',
      '3 sharing',
      'three sharing',
      'triple sharing',
    ])) {
      return ('triple', '3 Sharing');
    }
    if (_containsAnyPhrase(lower, ['4 sharing', 'four sharing'])) {
      return ('4 sharing', '4 Sharing');
    }
    return null;
  }

  static ({int value, bool isMax, Match match})? _extractCapacity(
    String lower,
  ) {
    final withUnit = RegExp(
      r'(?:(up\s*to|upto|under|below|less than|within|max(?:imum)?|not more than)'
              r'|(?:for|capacity(?:\s*of)?|seats?|fit|accommodate|above|over|more than|at least|min(?:imum)?))?'
              r'\s*(\d{1,5})\s*\+?\s*' +
          _capacityUnits +
          r'\b',
    );
    final m = withUnit.firstMatch(lower);
    if (m != null) {
      final value = int.tryParse(m.group(2)!);
      if (value != null && value > 0) {
        return (value: value, isMax: m.group(1) != null, match: m);
      }
    }
    final capOf = RegExp(r'capacity\s*(?:of\s*)?(\d{2,5})\b');
    final c = capOf.firstMatch(lower);
    if (c != null) {
      final value = int.tryParse(c.group(1)!);
      if (value != null && value > 0) {
        return (value: value, isMax: false, match: c);
      }
    }
    return null;
  }

  static ({double value, Match? match})? _extractRating(String lower) {
    double? valid(String? text) {
      final v = double.tryParse(text ?? '');
      if (v == null || v < 1 || v > 5) return null;
      return v;
    }

    final patterns = <RegExp>[
      // "4 star and above", "4+ stars", "4 stars or more"
      RegExp(
        r'(\d(?:\.\d)?)\s*(?:\+\s*)?(?:star|stars|★)\s*'
        r'(?:and above|& above|and up|or above|or more|or higher|plus|\+|and more|rated|rating)',
      ),
      RegExp(r'(\d(?:\.\d)?)\s*\+\s*(?:star|stars|★|rating|rated)'),
      // "rated above 4", "rating 4.5"
      RegExp(
        r'(?:rated|rating|ratings)\s*(?:of\s*)?'
        r'(?:above|over|at least|more than|>=?)?\s*(\d(?:\.\d)?)(?![\d,])',
      ),
      // "above 4", "over 4.5 stars" -- small numbers only, never guests/money.
      RegExp(
        r'(?:above|over|at least|more than)\s*(\d(?:\.\d)?)'
        r'(?![\d.,])(?!\s*(?:k\b|thousand|lakh|people|persons|guests|pax|members|seats|rs|rupees|inr))'
        r'(?:\s*(?:star|stars|★|rating|rated))?',
      ),
    ];
    for (final pattern in patterns) {
      final m = pattern.firstMatch(lower);
      final value = valid(m?.group(1));
      if (m != null && value != null) return (value: value, match: m);
    }
    if (_containsAny(lower, const [
      'top rated',
      'best rated',
      'highest rated',
      'highest rating',
      'best rating',
      'best reviews',
    ])) {
      return (value: 4.0, match: null);
    }
    return null;
  }

  static String _blank(String text, List<Match> spans) {
    var out = text;
    for (final m in spans) {
      if (m.end > out.length) continue;
      out = out.replaceRange(m.start, m.end, ' ' * (m.end - m.start));
    }
    return out;
  }

  static bool _hasPhrase(String text, String phrase) => RegExp(
    r'(?<![a-z0-9])' + RegExp.escape(phrase) + r'(?![a-z0-9])',
  ).hasMatch(text);

  static bool _containsAnyPhrase(String text, List<String> phrases) =>
      phrases.any((p) => _hasPhrase(text, p));

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
      'clean',
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

class _AmenitySpec {
  const _AmenitySpec(this.id, this.label, this.emoji, this.keywords);

  final String id;
  final String label;
  final String emoji;
  final List<String> keywords;
}
