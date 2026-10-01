import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/ai_booking/domain/ai_booking_intent.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the category key the assistant resolved, if any.
String? _categoryKey(String query) {
  for (final chip in AiBookingEngine.interpret(query).chips) {
    if (chip.slotKey == 'aiSlotCategory') return chip.valueKey;
  }
  return null;
}

AiIntentChip _chipFor(String query, String slotKey) {
  return AiBookingEngine.interpret(query)
      .chips
      .firstWhere((chip) => chip.slotKey == slotKey);
}

void main() {
  group('AiBookingEngine intent', () {
    test('an empty question is not understood', () {
      final intent = AiBookingEngine.interpret('   ');
      expect(intent.kind, AiBookingIntentKind.unrecognised);
      expect(intent.understood, isFalse);
      expect(intent.offersResults, isFalse);
      expect(intent.offersBookings, isFalse);
    });

    test('a question with no bookable signal is not understood', () {
      expect(
        AiBookingEngine.interpret('zz').kind,
        AiBookingIntentKind.unrecognised,
      );
    });

    test('understands a plain greeting', () {
      expect(
        AiBookingEngine.interpret('hello').kind,
        AiBookingIntentKind.greeting,
      );
      expect(
        AiBookingEngine.interpret('Hi there').kind,
        AiBookingIntentKind.greeting,
      );
    });

    test('understands greetings typed in the shipped languages', () {
      for (final greeting in const [
        'नमस्ते',
        'నమస్తే',
        'ನಮಸ್ಕಾರ',
        'வணக்கம்',
      ]) {
        expect(
          AiBookingEngine.interpret(greeting).kind,
          AiBookingIntentKind.greeting,
          reason: 'greeting not recognised: $greeting',
        );
      }
    });

    test('a greeting followed by a real request stays a request', () {
      final intent = AiBookingEngine.interpret('hello book a badminton court');
      expect(intent.kind, AiBookingIntentKind.bookNow);
      expect(intent.kind, isNot(AiBookingIntentKind.greeting));
    });

    test('a bare booking verb is not treated as a search', () {
      // "book" alone names nothing bookable, so the assistant asks again
      // instead of searching for the word "book".
      final intent = AiBookingEngine.interpret('book');
      expect(intent.kind, AiBookingIntentKind.unrecognised);
      expect(intent.chips, isEmpty);
    });

    test('reads a booking verb as a booking request', () {
      final intent =
          AiBookingEngine.interpret('book a function hall in Hyderabad');
      expect(intent.kind, AiBookingIntentKind.bookNow);
      expect(intent.offersResults, isTrue);
      expect(intent.query.categorySlug, 'function_halls');
      expect(intent.query.city, 'Hyderabad');
    });

    test('routes my-bookings and cancel requests to the bookings list', () {
      expect(
        AiBookingEngine.interpret('my bookings').kind,
        AiBookingIntentKind.showBookings,
      );
      expect(
        AiBookingEngine.interpret('show bookings').kind,
        AiBookingIntentKind.showBookings,
      );

      final cancel = AiBookingEngine.interpret('cancel my booking');
      expect(cancel.kind, AiBookingIntentKind.cancelBooking);
      expect(cancel.offersBookings, isTrue);
      expect(cancel.offersResults, isFalse);
    });

    test('treats a clear request as a reset', () {
      final intent = AiBookingEngine.interpret('clear filters');
      expect(intent.kind, AiBookingIntentKind.clearFilters);
      expect(intent.query.hasFilters, isFalse);
      expect(intent.offersResults, isTrue);
    });
  });

  group('AiBookingEngine slots', () {
    test('extracts category, city and budget', () {
      final intent = AiBookingEngine.interpret(
        'badminton courts in Hyderabad under 1000',
      );

      expect(intent.kind, AiBookingIntentKind.discoverVenues);
      expect(
          _chipFor('badminton courts in Hyderabad under 1000', 'aiSlotCategory')
              .valueKey,
          'aiCatBadminton');
      expect(
          _chipFor('badminton courts in Hyderabad under 1000', 'aiSlotLocation')
              .valueKey,
          'aiCityHyderabad');
      expect(
        _chipFor('badminton courts in Hyderabad under 1000', 'aiSlotBudget')
            .rawValue,
        '≤ ₹1,000',
      );

      expect(intent.query.categorySlug, 'sports_arena');
      expect(intent.query.city, 'Hyderabad');
      expect(intent.query.maxPrice, 1000);
    });

    test('groups budgets the Indian way', () {
      final intent =
          AiBookingEngine.interpret('marriage hall in Gachibowli under 50k');
      final budget =
          intent.chips.firstWhere((chip) => chip.slotKey == 'aiSlotBudget');
      expect(budget.rawValue, '≤ ₹50,000');
      expect(intent.query.maxPrice, 50000);
    });

    test('a budget chip is never translated, a category chip always is', () {
      final budget =
          _chipFor('badminton in Hyderabad under 1000', 'aiSlotBudget');
      expect(budget.isLocalized, isFalse);

      final category = _chipFor('badminton in Hyderabad', 'aiSlotCategory');
      expect(category.isLocalized, isTrue);
      expect(category.emoji, '🏸');
    });

    test('disambiguates the category slugs the parser shares', () {
      expect(_categoryKey('badminton courts in Hyderabad'), 'aiCatBadminton');
      expect(_categoryKey('cricket nets in Hyderabad'), 'aiCatCricket');
      expect(_categoryKey('football turf in Hyderabad'), 'aiCatFootball');
      expect(_categoryKey('marriage hall in Gachibowli'), 'aiCatMarriageHall');
      expect(_categoryKey('function hall in Gachibowli'), 'aiCatFunctionHall');
      expect(_categoryKey('ladies pg near Hitec City'), 'aiCatLadiesPg');
      expect(_categoryKey('gents pg near Hitec City'), 'aiCatGentsPg');
      expect(_categoryKey('pg near Hitec City'), 'aiCatPg');
      expect(_categoryKey('lodge rooms in Hyderabad'), 'aiCatLodge');
      expect(_categoryKey('coaching classes in Hyderabad'), 'aiCatClasses');
    });

    test('honours sort wording', () {
      final intent =
          AiBookingEngine.interpret('cheapest badminton courts in Hyderabad');
      final sort =
          intent.chips.firstWhere((chip) => chip.slotKey == 'aiSlotSort');
      expect(sort.valueKey, 'aiSortPriceLowToHigh');
      expect(intent.query.sortBy, VenueSortBy.priceAsc);
    });

    test('leaves out a sort chip when the customer did not ask for one', () {
      final intent = AiBookingEngine.interpret('badminton in Hyderabad');
      expect(
        intent.chips.any((chip) => chip.slotKey == 'aiSlotSort'),
        isFalse,
      );
      expect(intent.query.sortBy, VenueSortBy.relevance);
    });
  });

  group('AiBookingEngine in the shipped languages', () {
    test('understands a query typed in Telugu', () {
      const spoken = 'హైదరాబాద్ లో 1000 లోపు బ్యాడ్మింటన్';
      final intent = AiBookingEngine.interpret(spoken);

      expect(intent.kind, AiBookingIntentKind.discoverVenues);
      // The customer's own words are echoed back untouched.
      expect(intent.userText, spoken);
      expect(intent.query.categorySlug, 'sports_arena');
      expect(intent.query.city, 'Hyderabad');
      expect(intent.query.maxPrice, 1000);
    });

    test('understands a query typed in Hindi', () {
      final intent =
          AiBookingEngine.interpret('हैदराबाद में 1000 से कम का बैडमिंटन');
      expect(intent.kind, AiBookingIntentKind.discoverVenues);
      expect(intent.query.categorySlug, 'sports_arena');
      expect(intent.query.city, 'Hyderabad');
      expect(intent.query.maxPrice, 1000);
    });

    test('understands a query typed in Kannada', () {
      final intent =
          AiBookingEngine.interpret('ಹೈದರಾಬಾದ್ ನಲ್ಲಿ 1000 ಒಳಗೆ ಬ್ಯಾಡ್ಮಿಂಟನ್');
      expect(intent.kind, AiBookingIntentKind.discoverVenues);
      expect(intent.query.city, 'Hyderabad');
      expect(intent.query.maxPrice, 1000);
    });

    test('understands a query typed in Tamil', () {
      final intent =
          AiBookingEngine.interpret('ஹைதராபாத் இல் 1000 உள்ளே பேட்மிண்டன்');
      expect(intent.kind, AiBookingIntentKind.discoverVenues);
      expect(intent.query.city, 'Hyderabad');
      expect(intent.query.maxPrice, 1000);
    });

    test('a native-script word the table does not know cannot invent a filter',
        () {
      // Unknown native text produces no chips, so the assistant asks again
      // rather than searching for something it guessed at.
      final intent = AiBookingEngine.interpret('ఏదో తెలియని మాట');
      expect(intent.kind, AiBookingIntentKind.unrecognised);
      expect(intent.chips, isEmpty);
    });
  });

  group('assistant string table', () {
    const assistantKeys = <String>[
      'aiAssistantTitle',
      'aiAssistantSubtitle',
      'aiInputHint',
      'aiSend',
      'aiQuickTitle',
      'aiOnDeviceNote',
      'aiQuick1',
      'aiQuick2',
      'aiQuick3',
      'aiQuick4',
      'aiQuick5',
      'aiQuick6',
      'aiReplyGreeting',
      'aiReplyDiscover',
      'aiReplyBookNow',
      'aiReplyShowBookings',
      'aiReplyCancelBooking',
      'aiReplyClearFilters',
      'aiReplyUnrecognised',
      'aiShowResults',
      'aiOpenBookings',
      'aiSlotCategory',
      'aiSlotLocation',
      'aiSlotBudget',
      'aiSlotSort',
      'aiSlotKeyword',
      'aiCatBadminton',
      'aiCatCricket',
      'aiCatFootball',
      'aiCatMarriageHall',
      'aiCatFunctionHall',
      'aiCatPg',
      'aiCatGentsPg',
      'aiCatLadiesPg',
      'aiCatLodge',
      'aiCatClasses',
      'aiSortPriceLowToHigh',
      'aiSortTopRated',
      'aiCityHyderabad',
      'aiCityBangalore',
      'aiCityMumbai',
      'aiCityDelhi',
      'aiCityChennai',
      'aiCityPune',
      'aiCityKolkata',
    ];

    test('every shipped language translates every assistant string', () {
      // Languages this lineage ships full translations for. The release/v1.0
      // locales (mr, bn, gu, ml, es) fall back to English for these strings.
      const translated = {'en', 'te', 'hi', 'kn', 'ta'};
      for (final locale in AppLocalizations.supportedLocales
          .where((l) => translated.contains(l.languageCode))) {
        final l10n = AppLocalizations(locale);
        for (final key in assistantKeys) {
          final value = l10n.aiText(key);
          expect(value, isNot(key),
              reason: '$key is missing for ${locale.languageCode}');
          expect(value.trim(), isNotEmpty,
              reason: '$key is blank for ${locale.languageCode}');
          if (locale.languageCode != 'en') {
            expect(
              value,
              isNot(AppLocalizations.english(key)),
              reason: '$key is untranslated for ${locale.languageCode}',
            );
          }
        }
      }
    });

    test('every key the engine can emit exists in the table', () {
      const probes = [
        'hello',
        'badminton courts in Hyderabad under 1000',
        'book a marriage hall in Gachibowli under 50k',
        'cheapest gents pg in Bangalore',
        'my bookings',
        'cancel my booking',
        'clear filters',
        'zz',
      ];

      for (final probe in probes) {
        final intent = AiBookingEngine.interpret(probe);
        final keys = <String>[
          intent.replyKey,
          ...intent.quickKeys,
          for (final chip in intent.chips) ...[chip.slotKey, chip.valueKey],
        ];
        for (final key in keys) {
          if (key.isEmpty) continue;
          expect(
            AppLocalizations.english(key),
            isNot(key),
            reason: '"$probe" emitted unknown key $key',
          );
        }
      }
    });
  });
}
