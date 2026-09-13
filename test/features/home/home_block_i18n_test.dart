import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/home/domain/home_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeBlockConfig localized content', () {
    test('a language override wins over the base title', () {
      const block = HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        title: 'Top-rated spaces',
        titles: {'te': 'అత్యుత్తమ స్థలాలు'},
      );
      expect(block.titleFor('te'), 'అత్యుత్తమ స్థలాలు');
      expect(block.titleFor('en'), 'Top-rated spaces');
    });

    test('a language with no override falls back to the base title', () {
      const block = HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        title: 'Top-rated spaces',
      );
      for (final code in ['en', 'te', 'hi', 'kn', 'ta']) {
        expect(block.titleFor(code), 'Top-rated spaces');
      }
    });

    test('a blank override never blanks a section', () {
      const block = HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        title: 'Top-rated spaces',
        titles: {'hi': '   '},
      );
      expect(block.titleFor('hi'), 'Top-rated spaces');
    });

    test('subtitles resolve the same way', () {
      const block = HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        subtitle: 'Hand-picked for you',
        subtitles: {'ta': 'உங்களுக்காக'},
      );
      expect(block.subtitleFor('ta'), 'உங்களுக்காக');
      expect(block.subtitleFor('kn'), 'Hand-picked for you');
    });

    test('withTitle sets one language and leaves the rest alone', () {
      const block = HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        title: 'Top-rated spaces',
        titles: {'te': 'అత్యుత్తమ స్థలాలు'},
      );
      final updated = block.withTitle('hi', 'सर्वाधिक रेटेड जगहें');
      expect(updated.titleFor('hi'), 'सर्वाधिक रेटेड जगहें');
      expect(updated.titleFor('te'), 'అత్యుత్తమ స్థలాలు');
      expect(updated.title, 'Top-rated spaces');
    });

    test('clearing a language drops the override instead of storing blank', () {
      final block = const HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        title: 'Top-rated spaces',
      ).withTitle('hi', 'सर्वाधिक रेटेड जगहें');

      final cleared = block.withTitle('hi', '  ');
      expect(cleared.titles.containsKey('hi'), isFalse);
      expect(cleared.titleFor('hi'), 'Top-rated spaces');
    });

    test('localized content survives a JSON round-trip', () {
      final block = const HomeBlockConfig(
        kind: HomeBlockKind.spotlight,
        title: 'Top-rated spaces',
      )
          .withTitle('te', 'అత్యుత్తమ స్థలాలు')
          .withSubtitle('ta', 'உங்களுக்காக');

      final restored = HomeBlockConfig.fromJson(block.toJson(), block.kind);
      expect(restored.titleFor('te'), 'అత్యుత్తమ స్థలాలు');
      expect(restored.subtitleFor('ta'), 'உங்களுக்காக');
      expect(restored.title, 'Top-rated spaces');
    });

    test('a legacy single-language config still resolves everywhere', () {
      final appearance = HomeAppearance.fromJson(const {
        'blocks': [
          {'kind': 'spotlight', 'order': 30, 'title': 'Featured picks'},
        ],
      });
      final spotlight = appearance.blockFor(HomeBlockKind.spotlight)!;
      for (final code in ['en', 'te', 'hi', 'kn', 'ta']) {
        expect(spotlight.titleFor(code), 'Featured picks');
      }
    });

    test('blank entries in a stored map are dropped', () {
      final block = HomeBlockConfig.fromJson(const {
        'kind': 'spotlight',
        'titles': {'te': 'అత్యుత్తమ స్థలాలు', 'hi': '', 'kn': '   '},
      }, HomeBlockKind.spotlight);
      expect(block.titles.keys, ['te']);
    });
  });

  group('shipped Home defaults', () {
    test('do not pin an English heading into the config', () {
      final spotlight =
          HomeAppearance.defaults.blockFor(HomeBlockKind.spotlight)!;
      expect(spotlight.title, isEmpty);
      expect(spotlight.titles, isEmpty);
    });

    test('every shipped language has its own section headings', () {
      final english = AppLocalizations(const Locale('en'));
      expect(english.homeSpotlightTitle, 'Top-rated spaces');
      expect(english.homeCategoriesTitle, 'Listed categories');

      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        final code = locale.languageCode;
        expect(l10n.homeSpotlightTitle.trim(), isNotEmpty, reason: code);
        expect(l10n.homeCategoriesTitle.trim(), isNotEmpty, reason: code);
        if (code == 'en') continue;
        // `_t` falls back to English, so an untranslated key would silently
        // pass an "is it non-empty" check. Comparing against English catches it.
        expect(l10n.homeSpotlightTitle, isNot(english.homeSpotlightTitle),
            reason: 'spotlight heading not translated for $code');
        expect(l10n.homeCategoriesTitle, isNot(english.homeCategoriesTitle),
            reason: 'categories heading not translated for $code');
      }
    });
  });
}
