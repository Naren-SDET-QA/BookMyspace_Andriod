import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/home/presentation/home_category_catalog.dart';
import 'package:bookmyspace/features/cms/domain/cms_banner.dart';

CmsBanner _banner({
  bool isActive = true,
  String? iconName,
  String? accentColor,
  String? gradientStartColor,
  String? gradientEndColor,
  String? badgeColor,
}) {
  return CmsBanner(
    id: 'b1',
    title: 't',
    subtitle: 's',
    isActive: isActive,
    iconName: iconName,
    accentColor: accentColor,
    gradientStartColor: gradientStartColor,
    gradientEndColor: gradientEndColor,
    badgeColor: badgeColor,
  );
}

void main() {
  group('CmsCategoryStyle.tryParseHex', () {
    test('accepts #RRGGBB', () {
      expect(CmsCategoryStyle.tryParseHex('#7C3AED'), isNotNull);
    });

    test('accepts #AARRGGBB', () {
      expect(CmsCategoryStyle.tryParseHex('#FF7C3AED'), isNotNull);
    });

    test('accepts without a leading #', () {
      expect(CmsCategoryStyle.tryParseHex('7C3AED'), isNotNull);
    });

    test('rejects malformed values without throwing', () {
      expect(CmsCategoryStyle.tryParseHex('not-a-color'), isNull);
      expect(CmsCategoryStyle.tryParseHex('#12345'), isNull);
      expect(CmsCategoryStyle.tryParseHex(''), isNull);
      expect(CmsCategoryStyle.tryParseHex(null), isNull);
    });
  });

  group('CmsCategoryStyle.resolve', () {
    test('valid accent color overrides the section default', () {
      final style = CmsCategoryStyle.resolve(
        MainHomeSection.functionHalls,
        _banner(accentColor: '#00FFAA'),
      );
      expect(style.accentColor, const Color(0xFF00FFAA));
    });

    test(
        'invalid accent color falls back to the section default, never crashes',
        () {
      final fallback = MainHomeSection.functionHalls.accentColor;
      final style = CmsCategoryStyle.resolve(
        MainHomeSection.functionHalls,
        _banner(accentColor: 'garbage'),
      );
      expect(style.accentColor, fallback);
    });

    test('curated icon name resolves to a real icon', () {
      final style = CmsCategoryStyle.resolve(
        MainHomeSection.functionHalls,
        _banner(iconName: 'celebration'),
      );
      expect(style.icon, Icons.celebration_rounded);
    });

    test('unknown icon name falls back to null (caller keeps the emoji)', () {
      final style = CmsCategoryStyle.resolve(
        MainHomeSection.functionHalls,
        _banner(iconName: 'not_a_real_icon'),
      );
      expect(style.icon, isNull);
    });

    test('a disabled (unpublished) banner never contributes any override', () {
      final fallback = MainHomeSection.sportsTurfs.accentColor;
      final style = CmsCategoryStyle.resolve(
        MainHomeSection.sportsTurfs,
        _banner(
          isActive: false,
          accentColor: '#00FFAA',
          iconName: 'stadium',
        ),
      );
      expect(style.accentColor, fallback);
      expect(style.icon, isNull);
    });

    test('no banner at all uses every section default', () {
      final fallback = MainHomeSection.lodgeRooms.accentColor;
      final style = CmsCategoryStyle.resolve(MainHomeSection.lodgeRooms, null);
      expect(style.accentColor, fallback);
      expect(style.icon, isNull);
    });
  });
}
