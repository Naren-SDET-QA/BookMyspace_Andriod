import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/domain/cms_icon.dart';
import 'package:bookmyspace/features/cms/domain/cms_localized_text.dart';
import 'package:bookmyspace/features/home/presentation/home_category_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogContent.defaults mirrors the shipped hardcoded catalogue', () {
    test('one facility type per shipped discovery section, in order', () {
      final defaults = CatalogContent.defaults;
      expect(
        defaults.facilityTypes.length,
        MainHomeSection.discoveryOrder.length,
      );

      final orderedKeys =
          defaults.visible.map((type) => type.sections.single.key).toList();
      expect(
        orderedKeys,
        MainHomeSection.discoveryOrder.map((s) => s.id).toList(),
        reason: 'Function Halls must stay first, per product ordering',
      );
    });

    test('facility type keys match deployed parent_section values', () {
      for (final section in MainHomeSection.discoveryOrder) {
        final expectedKey = section.parentSectionAliases.first;
        final type = CatalogContent.defaults.facilityTypeFor(expectedKey);
        expect(type, isNotNull, reason: 'missing facility type $expectedKey');
        expect(type!.sections.single.key, section.id);
      }
    });

    test('every section carries its shipped wording, emoji and aliases', () {
      for (final section in MainHomeSection.discoveryOrder) {
        final node = CatalogContent.defaults.sectionFor(section.id);
        expect(node, isNotNull);
        expect(node!.title.base, section.title);
        expect(node.displayTitle.base, section.displayTitle);
        expect(node.description.base, section.subtitle);
        expect(node.emoji, section.emoji);
        expect(node.searchAliases, section.searchAliases);
      }
    });

    test('every section icon id resolves to the shipped IconData', () {
      // The whole point of storing an id instead of a code point: the default
      // document must still paint exactly what MainHomeSection.iconData does.
      for (final section in MainHomeSection.discoveryOrder) {
        final node = CatalogContent.defaults.sectionFor(section.id)!;
        expect(
          CmsIcon.resolve(node.iconId),
          section.iconData,
          reason: 'icon drift for ${section.id}',
        );
      }
    });

    test('shipped artwork survives as a media reference', () {
      for (final section in MainHomeSection.discoveryOrder) {
        final node = CatalogContent.defaults.sectionFor(section.id)!;
        expect(node.media.url, section.imageUrl);
      }
    });

    test('every subsection is carried across with label, emoji and aliases',
        () {
      for (final section in MainHomeSection.discoveryOrder) {
        final node = CatalogContent.defaults.sectionFor(section.id)!;
        expect(node.subsections.length, section.subSections.length);

        for (final shipped in section.subSections) {
          final match =
              node.subsections.where((s) => s.key == shipped.slug).toList();
          expect(match, hasLength(1), reason: 'missing ${shipped.slug}');
          expect(match.single.title.base, shipped.label);
          expect(match.single.emoji, shipped.emoji);
          expect(match.single.aliasSlugs, shipped.aliasSlugs);
        }
      }
    });

    test('Function Halls keeps all eight subsections', () {
      final node = CatalogContent.defaults.sectionFor('function_halls')!;
      expect(node.visibleSubsections, hasLength(8));
    });

    test('defaults survive a serialization round trip unchanged', () {
      final reparsed = CatalogContent.fromJson(CatalogContent.defaults.toJson());
      expect(reparsed.facilityTypes.length,
          CatalogContent.defaults.facilityTypes.length);

      for (final original in CatalogContent.defaults.facilityTypes) {
        final copy = reparsed.facilityTypeFor(original.key);
        expect(copy, isNotNull, reason: 'lost facility type ${original.key}');
        expect(copy!.sections.length, original.sections.length);
      }

      for (final section in MainHomeSection.discoveryOrder) {
        final copy = reparsed.sectionFor(section.id);
        expect(copy, isNotNull);
        expect(copy!.title.base, section.title);
        expect(copy.subsections.length, section.subSections.length);
        expect(CmsIcon.resolve(copy.iconId), section.iconData);
      }
    });
  });

  group('CatalogContent.fromJson falls back rather than failing', () {
    test('missing, wrong-typed and empty payloads yield the defaults', () {
      final expected = CatalogContent.defaults.facilityTypes.length;
      expect(CatalogContent.fromJson(null).facilityTypes, hasLength(expected));
      expect(
          CatalogContent.fromJson('nonsense').facilityTypes, hasLength(expected));
      expect(CatalogContent.fromJson(42).facilityTypes, hasLength(expected));
      expect(CatalogContent.fromJson(const []).facilityTypes,
          hasLength(expected));
      expect(CatalogContent.fromJson(const {}).facilityTypes,
          hasLength(expected));
      expect(
        CatalogContent.fromJson(const {'facility_types': 'nope'}).facilityTypes,
        hasLength(expected),
      );
      expect(
        CatalogContent.fromJson(const {'facility_types': []}).facilityTypes,
        hasLength(expected),
      );
    });

    test('a payload of only unusable entries yields the defaults', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          'not a map',
          42,
          {'key': ''},
          {'key': 'Has Spaces And Caps'},
          {'no_key': true},
        ],
      });
      expect(content.facilityTypes,
          hasLength(CatalogContent.defaults.facilityTypes.length));
    });

    test('a facility type missing from the payload is re-added from defaults',
        () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues', 'order': 1},
        ],
      });

      // The admin-supplied entry wins...
      expect(content.facilityTypeFor('venues')!.order, 1);
      // ...and everything they never mentioned is still present, so shipping a
      // new section never makes it vanish for an admin who saved earlier.
      for (final section in MainHomeSection.discoveryOrder) {
        expect(
          content.facilityTypeFor(section.parentSectionAliases.first),
          isNotNull,
          reason: 'lost ${section.parentSectionAliases.first}',
        );
      }
    });

    test('invalid nested entries are dropped without losing their parent', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {
            'key': 'venues',
            'sections': [
              {'key': 'BAD KEY', 'title': 'dropped'},
              {
                'key': 'function_halls',
                'title': 'Halls',
                'subsections': [
                  {'key': 'marriage_hall', 'title': 'Weddings'},
                  {'nope': true},
                  'garbage',
                ],
              },
            ],
          },
        ],
      });

      final type = content.facilityTypeFor('venues')!;
      expect(type.sections, hasLength(1));
      expect(type.sections.single.key, 'function_halls');
      expect(type.sections.single.subsections, hasLength(1));
      expect(type.sections.single.subsections.single.key, 'marriage_hall');
    });

    test('duplicate keys collapse to the first occurrence', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues', 'order': 1},
          {'key': 'venues', 'order': 99},
        ],
      });
      expect(content.facilityTypeFor('venues')!.order, 1);
    });

    test('an unknown icon id degrades to the fallback glyph', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues', 'icon': 'no_such_icon'},
        ],
      });
      final type = content.facilityTypeFor('venues')!;
      expect(type.iconId, CmsIcon.fallbackId);
      expect(CmsIcon.resolve(type.iconId), CmsIcon.fallback);
    });

    test('an unusable media url is dropped rather than rendered', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues', 'media': 'javascript:alert(1)'},
        ],
      });
      expect(content.facilityTypeFor('venues')!.media.isEmpty, isTrue);
    });
  });

  group('ordering and visibility', () {
    test('disabled entries are hidden but retained', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues', 'enabled': false, 'order': 1},
          {'key': 'sports', 'order': 2},
        ],
      });
      expect(content.facilityTypeFor('venues'), isNotNull);
      expect(content.visible.map((t) => t.key), isNot(contains('venues')));
      expect(content.visible.first.key, 'sports');
    });

    test('a duplicated order still yields a stable sequence', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'sports', 'order': 5},
          {'key': 'pgs', 'order': 5},
          {'key': 'classes', 'order': 5},
        ],
      });
      final first = content.visible.map((t) => t.key).toList();
      final second = content.visible.map((t) => t.key).toList();
      expect(first, second);
      expect(first.take(3), ['classes', 'pgs', 'sports']);
    });

    test('subsection order and visibility are honoured', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {
            'key': 'venues',
            'sections': [
              {
                'key': 'function_halls',
                'subsections': [
                  {'key': 'party_hall', 'order': 30},
                  {'key': 'marriage_hall', 'order': 10},
                  {'key': 'banquet_hall', 'order': 20, 'enabled': false},
                ],
              },
            ],
          },
        ],
      });
      final section = content.sectionFor('function_halls')!;
      expect(section.visibleSubsections.map((s) => s.key),
          ['marriage_hall', 'party_hall']);
      expect(section.subsections, hasLength(3),
          reason: 'disabled entries stay in the document');
    });
  });

  group('localization and text fallback', () {
    test('per-language overrides resolve, and fall back to the base', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {
            'key': 'venues',
            'sections': [
              {
                'key': 'function_halls',
                'title': {
                  'base': 'Function Halls',
                  'i18n': {'te': 'ఫంక్షన్ హాల్స్'},
                },
              },
            ],
          },
        ],
      });
      final section = content.sectionFor('function_halls')!;
      expect(section.titleFor('te'), 'ఫంక్షన్ హాల్స్');
      expect(section.titleFor('en'), 'Function Halls');
      expect(section.titleFor('hi'), 'Function Halls');
    });

    test('an absent title falls back to the caller-supplied l10n string', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {
            'key': 'venues',
            'sections': [
              {'key': 'function_halls'},
            ],
          },
        ],
      });
      final section = content.sectionFor('function_halls')!;
      expect(section.titleFor('en', fallback: 'Shipped heading'),
          'Shipped heading');
    });

    test('displayTitle falls back to title, then to the l10n string', () {
      const withTitleOnly = CatalogSection(
        key: 'function_halls',
        title: CmsLocalizedText(base: 'Halls'),
      );
      expect(withTitleOnly.displayTitleFor('en'), 'Halls');

      const bare = CatalogSection(key: 'function_halls');
      expect(bare.displayTitleFor('en', fallback: 'Shipped'), 'Shipped');
    });

    test('Telugu text survives a round trip', () {
      const original = CatalogSection(
        key: 'function_halls',
        title: CmsLocalizedText(
          base: 'Function Halls',
          overrides: {'te': 'ఫంక్షన్ హాల్స్', 'ta': 'மண்டபங்கள்'},
        ),
      );
      final copy = CatalogSection.fromJson(original.toJson())!;
      expect(copy.titleFor('te'), 'ఫంక్షన్ హాల్స్');
      expect(copy.titleFor('ta'), 'மண்டபங்கள்');
      expect(copy.titleFor('en'), 'Function Halls');
    });
  });
}
