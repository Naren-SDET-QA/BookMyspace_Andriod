import '../../search/domain/voice_filter_parser.dart';
import '../../venues/domain/venue.dart';

/// What the customer is actually asking the booking assistant to do.
///
/// The assistant is deliberately deterministic: it understands the same
/// vocabulary the shipped voice-search parser already understands, then layers
/// booking verbs on top. Nothing here talks to a network, and nothing here can
/// create, confirm or cancel a booking — every intent ends with the customer
/// opening a real, RLS-protected screen and confirming there.
enum AiBookingIntentKind {
  greeting,
  discoverVenues,
  bookNow,
  showBookings,
  cancelBooking,
  clearFilters,
  unrecognised,
}

/// One interpreted slot of the customer's request.
///
/// Values that are part of the app's own vocabulary carry a [valueKey] so the
/// UI can render them in the active language. Anything else (a budget, a free
/// text keyword) keeps its [rawValue] verbatim.
class AiIntentChip {
  const AiIntentChip({
    required this.emoji,
    required this.slotKey,
    this.valueKey = '',
    this.rawValue = '',
  });

  final String emoji;

  /// Localization key for the chip's role, e.g. `aiSlotCategory`.
  final String slotKey;

  /// Localization key for a known value. Empty when [rawValue] should be used.
  final String valueKey;

  /// Untranslated value shown as-is (budgets, free text, place names).
  final String rawValue;

  /// True when the chip resolves through the localization table.
  bool get isLocalized => valueKey.isNotEmpty;
}

/// A single, fully interpreted request from the customer.
class AiBookingIntent {
  const AiBookingIntent({
    required this.kind,
    required this.userText,
    required this.replyKey,
    this.query = const VenueSearchQuery(),
    this.chips = const [],
    this.quickKeys = const [],
  });

  final AiBookingIntentKind kind;

  /// Exactly what the customer typed or said, echoed back unchanged.
  final String userText;

  /// Localization key for the assistant's reply.
  final String replyKey;

  /// The structured filter the request resolved to.
  final VenueSearchQuery query;

  final List<AiIntentChip> chips;

  /// Localization keys for follow-up suggestions.
  final List<String> quickKeys;

  /// True when tapping through to venue results is the useful next step.
  bool get offersResults =>
      kind == AiBookingIntentKind.discoverVenues ||
      kind == AiBookingIntentKind.bookNow ||
      kind == AiBookingIntentKind.clearFilters;

  /// True when the customer should land on their bookings list instead.
  bool get offersBookings =>
      kind == AiBookingIntentKind.showBookings ||
      kind == AiBookingIntentKind.cancelBooking;

  bool get understood => kind != AiBookingIntentKind.unrecognised;
}

/// Turns plain language into a structured booking intent.
///
/// Runs entirely on-device and is a pure function of its input, which keeps it
/// cheap to call on every keystroke and trivial to test.
class AiBookingEngine {
  const AiBookingEngine._();

  static AiBookingIntent interpret(String text) {
    final raw = text.trim();
    if (raw.isEmpty) {
      return const AiBookingIntent(
        kind: AiBookingIntentKind.unrecognised,
        userText: '',
        replyKey: 'aiReplyUnrecognised',
      );
    }

    // The shipped parser matches English keywords, so native-language terms are
    // normalised first. The customer's own words are still echoed back.
    final normalized = _normalize(raw);
    final lower = normalized.toLowerCase();

    if (_isGreeting(lower)) {
      return AiBookingIntent(
        kind: AiBookingIntentKind.greeting,
        userText: raw,
        replyKey: 'aiReplyGreeting',
        quickKeys: const [
          'aiQuick1',
          'aiQuick2',
          'aiQuick3',
          'aiQuick4',
        ],
      );
    }

    final parsed = VoiceCommandFilterParser.parse(normalized);

    if (parsed.isClearCommand) {
      return AiBookingIntent(
        kind: AiBookingIntentKind.clearFilters,
        userText: raw,
        replyKey: 'aiReplyClearFilters',
        quickKeys: const ['aiQuick1'],
      );
    }

    if (_isCancelBooking(lower)) {
      return AiBookingIntent(
        kind: AiBookingIntentKind.cancelBooking,
        userText: raw,
        replyKey: 'aiReplyCancelBooking',
      );
    }

    if (_isShowBookings(lower)) {
      return AiBookingIntent(
        kind: AiBookingIntentKind.showBookings,
        userText: raw,
        replyKey: 'aiReplyShowBookings',
      );
    }

    // The parser keeps booking verbs such as "book" or "slots" in the keyword,
    // which would search for the verb itself. Strip them before deciding
    // whether the customer actually named something bookable.
    final keyword = _keywordFrom(parsed.cleanedSearchQuery);
    final query = parsed.toVenueSearchQuery().copyWith(query: keyword);
    final chips = _chipsFor(parsed, keyword);
    final hasSignal = chips.isNotEmpty;

    if (_isBookNow(lower) && hasSignal) {
      return AiBookingIntent(
        kind: AiBookingIntentKind.bookNow,
        userText: raw,
        replyKey: 'aiReplyBookNow',
        query: query,
        chips: chips,
        quickKeys: const ['aiQuick5'],
      );
    }

    if (hasSignal) {
      return AiBookingIntent(
        kind: AiBookingIntentKind.discoverVenues,
        userText: raw,
        replyKey: 'aiReplyDiscover',
        query: query,
        chips: chips,
        quickKeys: const ['aiQuick5', 'aiQuick6'],
      );
    }

    return AiBookingIntent(
      kind: AiBookingIntentKind.unrecognised,
      userText: raw,
      replyKey: 'aiReplyUnrecognised',
      quickKeys: const ['aiQuick1', 'aiQuick2', 'aiQuick4'],
    );
  }

  // --- Native-language normalisation ----------------------------------------

  /// Maps the words customers actually type in each shipped language onto the
  /// English keywords the parser matches.
  ///
  /// Longer phrases are listed before the shorter words they contain, because
  /// entries are applied in order. A term that is missing here simply yields an
  /// "unrecognised" reply — it can never produce a wrong filter silently.
  static const Map<String, String> _nativeAliases = {
    // Places
    'हैदराबाद': ' Hyderabad ',
    'बेंगलुरु': ' Bangalore ',
    'मुंबई': ' Mumbai ',
    'दिल्ली': ' Delhi ',
    'चेन्नई': ' Chennai ',
    'पुणे': ' Pune ',
    'कोलकाता': ' Kolkata ',
    'गच्चीबोवली': ' gachibowli ',
    'हाईटेक सिटी': ' hitec city ',
    'హైదరాబాద్': ' Hyderabad ',
    'బెంగళూరు': ' Bangalore ',
    'ముంబై': ' Mumbai ',
    'ఢిల్లీ': ' Delhi ',
    'చెన్నై': ' Chennai ',
    'పూనే': ' Pune ',
    'కోల్‌కతా': ' Kolkata ',
    'గచ్చిబౌలి': ' gachibowli ',
    'హైటెక్ సిటీ': ' hitec city ',
    'ಹೈದರಾಬಾದ್': ' Hyderabad ',
    'ಬೆಂಗಳೂರು': ' Bangalore ',
    'ಮುಂಬೈ': ' Mumbai ',
    'ದೆಹಲಿ': ' Delhi ',
    'ಚೆನ್ನೈ': ' Chennai ',
    'ಪುಣೆ': ' Pune ',
    'ಕೋಲ್ಕತ್ತಾ': ' Kolkata ',
    'ಗಚ್ಚಿಬೌಳಿ': ' gachibowli ',
    'ಹೈಟೆಕ್ ಸಿಟಿ': ' hitec city ',
    'ஹைதராபாத்': ' Hyderabad ',
    'பெங்களூரு': ' Bangalore ',
    'மும்பை': ' Mumbai ',
    'டெல்லி': ' Delhi ',
    'சென்னை': ' Chennai ',
    'புனே': ' Pune ',
    'கொல்கத்தா': ' Kolkata ',
    'கச்சிபவுலி': ' gachibowli ',
    'ஹைடெக் சிட்டி': ' hitec city ',

    // Categories
    'बैडमिंटन': ' badminton ',
    'क्रिकेट': ' cricket ',
    'फुटबॉल': ' football ',
    'मैरिज हॉल': ' marriage hall ',
    'शादी': ' marriage hall ',
    'फंक्शन हॉल': ' function hall ',
    'बैंक्वेट': ' banquet ',
    'हॉस्टल': ' hostel ',
    'पीजी': ' pg ',
    'होटल': ' hotel ',
    'कोचिंग': ' coaching ',
    'బ్యాడ్మింటన్': ' badminton ',
    'క్రికెట్': ' cricket ',
    'ఫుట్‌బాల్': ' football ',
    'మ్యారేజ్ హాల్': ' marriage hall ',
    'పెళ్లి': ' marriage hall ',
    'ఫంక్షన్ హాల్': ' function hall ',
    'హాస్టల్': ' hostel ',
    'పీజీ': ' pg ',
    'హోటల్': ' hotel ',
    'కోచింగ్': ' coaching ',
    'ಬ್ಯಾಡ್ಮಿಂಟನ್': ' badminton ',
    'ಕ್ರಿಕೆಟ್': ' cricket ',
    'ಫುಟ್‌ಬಾಲ್': ' football ',
    'ಮ್ಯಾರೇಜ್ ಹಾಲ್': ' marriage hall ',
    'ಮದುವೆ': ' marriage hall ',
    'ಫಂಕ್ಷನ್ ಹಾಲ್': ' function hall ',
    'ಹಾಸ್ಟೆಲ್': ' hostel ',
    'ಪಿಜಿ': ' pg ',
    'ಹೋಟೆಲ್': ' hotel ',
    'ಕೋಚಿಂಗ್': ' coaching ',
    'பேட்மிண்டன்': ' badminton ',
    'கிரிக்கெட்': ' cricket ',
    'கால்பந்து': ' football ',
    'திருமண மண்டபம்': ' marriage hall ',
    'திருமணம்': ' marriage hall ',
    'விழா மண்டபம்': ' function hall ',
    'தங்கும் விடுதி': ' hostel ',
    'ஹோட்டல்': ' hotel ',
    'பயிற்சி': ' coaching ',

    // Audience
    'लेडीज़': ' ladies ',
    'जेंट्स': ' gents ',
    'లేడీస్': ' ladies ',
    'జెంట్స్': ' gents ',
    'ಲೇಡೀಸ್': ' ladies ',
    'ಜೆಂಟ್ಸ್': ' gents ',
    'மகளிர் விடுதி': ' ladies pg ',
    'மகளிர்': ' ladies ',
    'ஆண்கள் விடுதி': ' gents pg ',
    'ஆண்கள்': ' gents ',

    // Budget wording
    'से कम': ' under ',
    'हज़ार': ' k ',
    'हजार': ' k ',
    'లోపు': ' under ',
    'వేల': ' k ',
    'ಒಳಗೆ': ' under ',
    'ಸಾವಿರ': ' k ',
    'உள்ளே': ' under ',
    'ஆயிரம்': ' k ',
  };

  /// Matches an amount that precedes the word "under", which is the natural
  /// word order in every Indian language the app ships.
  ///
  /// The middle group absorbs short suffixes glued to the number, as in the
  /// Tamil "1000க்கு".
  static final RegExp _amountBeforeUnder = RegExp(
    r'(\d[\d,]*)(\s*k)?[^\d\s]{0,10}?\s+under\b',
    caseSensitive: false,
  );

  static String _normalize(String text) {
    var out = text;
    for (final entry in _nativeAliases.entries) {
      if (out.contains(entry.key)) {
        out = out.replaceAll(entry.key, entry.value);
      }
    }
    // "1000 లోపు" has to become "under 1000" before the shipped price regex,
    // which only understands the English word order, can see it.
    return out.replaceAllMapped(
      _amountBeforeUnder,
      (match) => ' under ${match.group(1)}${match.group(2) ?? ''} ',
    );
  }

  // --- Intent detection -----------------------------------------------------

  static const Set<String> _greetingWords = {
    'hi',
    'hii',
    'hey',
    'hello',
    'helo',
    'namaste',
    'namaskar',
    'there',
    'good',
    'morning',
    'afternoon',
    'evening',
    'yo',
  };

  /// Greetings typed in the languages the app ships, so "నమస్తే" and "வணக்கம்"
  /// are understood the same way "hello" is.
  static const List<String> _nativeGreetings = [
    'नमस्ते',
    'नमस्कार',
    'నమస్తే',
    'నమస్కారం',
    'ನಮಸ್ಕಾರ',
    'வணக்கம்',
    'हाय',
    'హాయ్',
  ];

  static bool _isGreeting(String text) {
    if (_nativeGreetings.any(text.contains)) return true;
    final words = text
        .split(RegExp(r'[^a-z]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return false;
    // Every word must be a greeting, so "hello, book a turf" stays a request.
    return words.every(_greetingWords.contains);
  }

  static bool _isShowBookings(String text) => _hasAny(text, const [
        'my booking',
        'my bookings',
        'booking status',
        'my pass',
        'my passes',
        'upcoming booking',
        'upcoming bookings',
        'show bookings',
        'my reservation',
        'my reservations',
      ]);

  static bool _isCancelBooking(String text) => _hasAny(text, const [
        'cancel my booking',
        'cancel booking',
        'cancel the booking',
        'cancel my pass',
        'cancel my reservation',
      ]);

  static bool _isBookNow(String text) => _hasAny(text, const [
        'book',
        'booking',
        'reserve',
        'reservation',
        'available slot',
        'availability',
        'open slot',
        'free slot',
        'slots',
        'when can i',
        'check availability',
      ]);

  /// Booking verbs the parser leaves behind in the free-text keyword.
  static const List<String> _intentWords = [
    'bookings',
    'booking',
    'book',
    'reservations',
    'reservation',
    'reserve',
    'availability',
    'available',
    'slots',
    'slot',
  ];

  /// Rebuilds the free-text keyword from tokens the parser can actually match.
  ///
  /// Booking verbs are dropped, and so is any leftover native-script word the
  /// alias table did not translate — keeping it would only show the customer
  /// noise in the chip while never matching a venue.
  static String _keywordFrom(String value) {
    var out = value;
    for (final word in _intentWords) {
      out = out.replaceAll(
        RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false),
        ' ',
      );
    }
    final tokens = out
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => RegExp(r"^[a-z0-9\-']+$").hasMatch(token));
    return tokens.join(' ').trim();
  }

  // --- Slot extraction ------------------------------------------------------

  static List<AiIntentChip> _chipsFor(
      VoiceFilterResult parsed, String keyword) {
    final chips = <AiIntentChip>[];

    final category = _categoryFor(parsed);
    if (category != null) {
      chips.add(AiIntentChip(
        emoji: _categoryEmoji[category] ?? '🏷️',
        slotKey: 'aiSlotCategory',
        valueKey: category,
      ));
    }

    final city = parsed.city;
    if (city != null) {
      final cityKey = _cityKeys[city];
      chips.add(AiIntentChip(
        emoji: '📍',
        slotKey: 'aiSlotLocation',
        valueKey: cityKey ?? '',
        rawValue: cityKey == null ? city : '',
      ));
    }

    if (parsed.maxPrice != null) {
      chips.add(AiIntentChip(
        emoji: '💰',
        slotKey: 'aiSlotBudget',
        rawValue: '≤ ₹${_grouped(parsed.maxPrice!)}',
      ));
    }

    if (parsed.minPrice != null) {
      chips.add(AiIntentChip(
        emoji: '💵',
        slotKey: 'aiSlotBudget',
        rawValue: '≥ ₹${_grouped(parsed.minPrice!)}',
      ));
    }

    if (parsed.sortBy != VenueSortBy.relevance) {
      chips.add(AiIntentChip(
        emoji: parsed.sortBy == VenueSortBy.priceAsc ? '🏷️' : '⭐',
        slotKey: 'aiSlotSort',
        valueKey: parsed.sortBy == VenueSortBy.priceAsc
            ? 'aiSortPriceLowToHigh'
            : 'aiSortTopRated',
      ));
    }

    if (keyword.isNotEmpty) {
      chips.add(AiIntentChip(
        emoji: '🔎',
        slotKey: 'aiSlotKeyword',
        rawValue: keyword,
      ));
    }

    return chips;
  }

  /// Maps the parser's category slug onto a localized label.
  ///
  /// Sports, function halls and PGs share one slug each, so the customer's own
  /// words disambiguate which label is shown.
  static String? _categoryFor(VoiceFilterResult parsed) {
    final slug = parsed.categorySlug;
    if (slug == null) return null;
    final text = parsed.rawSpokenText.toLowerCase();

    switch (slug) {
      case 'sports_arena':
        if (_hasAny(text, const ['badminton', 'shuttle'])) {
          return 'aiCatBadminton';
        }
        if (_hasAny(text, const ['cricket', 'pitch', 'nets'])) {
          return 'aiCatCricket';
        }
        return 'aiCatFootball';
      case 'function_halls':
        return _hasAny(text, const ['marriage', 'wedding', 'kalyana', 'shadi'])
            ? 'aiCatMarriageHall'
            : 'aiCatFunctionHall';
      case 'pg_hostels':
        if (_hasAny(text, const ['gents', 'men', 'boys', 'male'])) {
          return 'aiCatGentsPg';
        }
        if (_hasAny(text, const ['ladies', 'women', 'girls', 'female'])) {
          return 'aiCatLadiesPg';
        }
        return 'aiCatPg';
      case 'lodge_rooms':
        return 'aiCatLodge';
      case 'institutes_classes':
        return 'aiCatClasses';
    }
    return null;
  }

  static const Map<String, String> _categoryEmoji = {
    'aiCatBadminton': '🏸',
    'aiCatCricket': '🏏',
    'aiCatFootball': '⚽',
    'aiCatMarriageHall': '💍',
    'aiCatFunctionHall': '🏛️',
    'aiCatPg': '🏠',
    'aiCatGentsPg': '👨',
    'aiCatLadiesPg': '👩',
    'aiCatLodge': '🏨',
    'aiCatClasses': '🎓',
  };

  static const Map<String, String> _cityKeys = {
    'Hyderabad': 'aiCityHyderabad',
    'Bangalore': 'aiCityBangalore',
    'Mumbai': 'aiCityMumbai',
    'Delhi': 'aiCityDelhi',
    'Chennai': 'aiCityChennai',
    'Pune': 'aiCityPune',
    'Kolkata': 'aiCityKolkata',
  };

  static bool _hasAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }

  /// Indian digit grouping, so 50000 reads as `50,000` and 100000 as `1,00,000`.
  static String _grouped(double value) {
    final digits = value.round().abs().toString();
    if (digits.length <= 3) return digits;
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    final buffer = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 2 == 0) buffer.write(',');
      buffer.write(head[i]);
    }
    return '$buffer,$tail';
  }
}
