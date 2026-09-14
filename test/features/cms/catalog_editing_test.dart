import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/domain/cms_localized_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shipped facility type keys, taken from the generated defaults rather than
/// retyped so these tests follow the catalogue if product reorders it.
String _firstShippedTypeKey() => CatalogContent.defaults.facilityTypes.first.key;

void main() {
  group('facility types', () {
    test('upsert inserts a new type and keeps list position on replace', () {
      final base = CatalogContent.defaults;
      const added = CatalogFacilityType(
        key: 'stays',
        title: CmsLocalizedText(base: 'Stays'),
        order: 99,
      );

      final withNew = base.upsertFacilityType(added);
      expect(withNew.facilityTypeFor('stays')!.title.base, 'Stays');
      expect(withNew.facilityTypes.length, base.facilityTypes.length + 1);

      final firstKey = _firstShippedTypeKey();
      final original = withNew.facilityTypeFor(firstKey)!;
      final replaced = withNew.upsertFacilityType(
        original.copyWith(title: const CmsLocalizedText(base: 'Renamed')),
      );
      expect(replaced.facilityTypes.length, withNew.facilityTypes.length);
      expect(replaced.facilityTypes.first.key, firstKey,
          reason: 'replacing must not move the entry to the end');
      expect(replaced.facilityTypeFor(firstKey)!.title.base, 'Renamed');
    });

    test('a shipped facility type cannot be deleted', () {
      final key = _firstShippedTypeKey();
      expect(CatalogContent.isShippedFacilityType(key), isTrue);

      final after = CatalogContent.defaults.removeFacilityType(key);
      expect(after.facilityTypeFor(key), isNotNull,
          reason: 'fromJson re-adds shipped types, so a delete would return');
    });

    test('a custom facility type can be deleted', () {
      final withCustom = CatalogContent.defaults.upsertFacilityType(
        const CatalogFacilityType(
          key: 'stays',
          title: CmsLocalizedText(base: 'Stays'),
        ),
      );
      expect(CatalogContent.isShippedFacilityType('stays'), isFalse);

      final after = withCustom.removeFacilityType('stays');
      expect(after.facilityTypeFor('stays'), isNull);
    });

    test('deleting a shipped type is a no-op, not a silent partial edit', () {
      final key = _firstShippedTypeKey();
      final before = CatalogContent.defaults;
      final after = before.removeFacilityType(key);
      expect(after.facilityTypes.length, before.facilityTypes.length);
    });
  });

  group('sections', () {
    test('upsert adds under the named type and replaces in place', () {
      final typeKey = _firstShippedTypeKey();
      final base = CatalogContent.defaults;
      final originalCount = base.facilityTypeFor(typeKey)!.sections.length;

      final added = base.upsertSection(
        typeKey,
        const CatalogSection(
          key: 'rooftop_venues',
          title: CmsLocalizedText(base: 'Rooftops'),
        ),
      );
      expect(added.facilityTypeFor(typeKey)!.sections.length,
          originalCount + 1);
      expect(added.sectionFor('rooftop_venues')!.title.base, 'Rooftops');

      final replaced = added.upsertSection(
        typeKey,
        added.sectionFor('rooftop_venues')!
            .copyWith(title: const CmsLocalizedText(base: 'Terraces')),
      );
      expect(replaced.facilityTypeFor(typeKey)!.sections.length,
          originalCount + 1);
      expect(replaced.sectionFor('rooftop_venues')!.title.base, 'Terraces');
    });

    test('upsert into an unknown type is a no-op', () {
      final base = CatalogContent.defaults;
      final after = base.upsertSection(
        'no_such_type',
        const CatalogSection(key: 'orphan'),
      );
      expect(after.sectionFor('orphan'), isNull);
      expect(after.facilityTypes.length, base.facilityTypes.length);
    });

    test('removing a section takes its subsections with it', () {
      final typeKey = _firstShippedTypeKey();
      final sectionKey =
          CatalogContent.defaults.facilityTypeFor(typeKey)!.sections.first.key;
      expect(
        CatalogContent.defaults.sectionFor(sectionKey)!.subsections,
        isNotEmpty,
      );

      final after =
          CatalogContent.defaults.removeSection(typeKey, sectionKey);
      expect(after.sectionFor(sectionKey), isNull);
      expect(after.facilityTypeFor(typeKey), isNotNull,
          reason: 'the parent type survives');
    });

    test('facilityTypeOfSection finds the owner', () {
      final typeKey = _firstShippedTypeKey();
      final sectionKey =
          CatalogContent.defaults.facilityTypeFor(typeKey)!.sections.first.key;
      expect(
        CatalogContent.defaults.facilityTypeOfSection(sectionKey)!.key,
        typeKey,
      );
      expect(CatalogContent.defaults.facilityTypeOfSection('nope'), isNull);
    });
  });

  group('subsections', () {
    test('upsert adds and replaces under the named section', () {
      final typeKey = _firstShippedTypeKey();
      final sectionKey =
          CatalogContent.defaults.facilityTypeFor(typeKey)!.sections.first.key;
      final before =
          CatalogContent.defaults.sectionFor(sectionKey)!.subsections.length;

      final added = CatalogContent.defaults.upsertSubsection(
        typeKey,
        sectionKey,
        const CatalogSubsection(
          key: 'rooftop_lounge',
          title: CmsLocalizedText(base: 'Rooftop lounge'),
        ),
      );
      expect(added.sectionFor(sectionKey)!.subsections.length, before + 1);

      final replaced = added.upsertSubsection(
        typeKey,
        sectionKey,
        const CatalogSubsection(
          key: 'rooftop_lounge',
          title: CmsLocalizedText(base: 'Sky lounge'),
        ),
      );
      expect(replaced.sectionFor(sectionKey)!.subsections.length, before + 1);
      final match = replaced
          .sectionFor(sectionKey)!
          .subsections
          .firstWhere((s) => s.key == 'rooftop_lounge');
      expect(match.title.base, 'Sky lounge');
    });

    test('upsert into an unknown section is a no-op', () {
      final typeKey = _firstShippedTypeKey();
      final after = CatalogContent.defaults.upsertSubsection(
        typeKey,
        'no_such_section',
        const CatalogSubsection(key: 'orphan'),
      );
      expect(
        after.facilityTypeFor(typeKey)!.sections.every(
              (s) => s.subsections.every((x) => x.key != 'orphan'),
            ),
        isTrue,
      );
    });

    test('remove drops only the named subsection', () {
      final typeKey = _firstShippedTypeKey();
      final section =
          CatalogContent.defaults.facilityTypeFor(typeKey)!.sections.first;
      final victim = section.subsections.first.key;

      final after = CatalogContent.defaults
          .removeSubsection(typeKey, section.key, victim);
      final remaining = after.sectionFor(section.key)!.subsections;
      expect(remaining.length, section.subsections.length - 1);
      expect(remaining.any((s) => s.key == victim), isFalse);
    });
  });

  group('key uniqueness', () {
    test('containsKey sees every level', () {
      final content = CatalogContent.defaults;
      final typeKey = content.facilityTypes.first.key;
      final section = content.facilityTypes.first.sections.first;

      expect(content.containsKey(typeKey), isTrue);
      expect(content.containsKey(section.key), isTrue);
      expect(content.containsKey(section.subsections.first.key), isTrue);
      expect(content.containsKey('definitely_not_used'), isFalse);
    });
  });

  group('edits survive a publish round trip', () {
    test('an edited document reloads with the edit intact', () {
      final typeKey = _firstShippedTypeKey();
      final edited = CatalogContent.defaults.upsertFacilityType(
        CatalogContent.defaults.facilityTypeFor(typeKey)!.copyWith(
              title: const CmsLocalizedText(
                base: 'Celebrations',
                overrides: {'te': 'వేడుకలు'},
              ),
              enabled: false,
            ),
      );

      final reloaded = CatalogContent.fromJson(edited.toJson());
      final type = reloaded.facilityTypeFor(typeKey)!;
      expect(type.title.base, 'Celebrations');
      expect(type.title.resolve('te'), 'వేడుకలు');
      expect(type.enabled, isFalse);
      expect(reloaded.visible.any((t) => t.key == typeKey), isFalse);
    });

    test('a custom type and section survive the round trip', () {
      final edited = CatalogContent.defaults
          .upsertFacilityType(const CatalogFacilityType(
            key: 'stays',
            title: CmsLocalizedText(base: 'Stays'),
            order: 60,
          ))
          .upsertSection(
            'stays',
            const CatalogSection(
              key: 'serviced_apartments',
              title: CmsLocalizedText(base: 'Serviced apartments'),
              searchAliases: ['serviced_apartment'],
            ),
          );

      final reloaded = CatalogContent.fromJson(edited.toJson());
      expect(reloaded.facilityTypeFor('stays')!.title.base, 'Stays');
      expect(reloaded.sectionFor('serviced_apartments')!.searchAliases,
          ['serviced_apartment']);
    });
  });
}
