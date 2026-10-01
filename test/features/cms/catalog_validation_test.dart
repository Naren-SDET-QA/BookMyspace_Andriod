import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/domain/catalog_validation.dart';
import 'package:bookmyspace/features/cms/domain/cms_localized_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('key validation', () {
    test('accepts lowercase slugs', () {
      expect(CatalogValidator.fieldKey('marriage_hall'), isNull);
      expect(CatalogValidator.fieldKey('hall2'), isNull);
      expect(CatalogValidator.fieldKey('rooftop-venues'), isNull);
    });

    test('rejects empty, spaced, uppercase and over-long ids', () {
      expect(CatalogValidator.fieldKey(''), isNotNull);
      expect(CatalogValidator.fieldKey('   '), isNotNull);
      expect(CatalogValidator.fieldKey('Marriage Hall'), isNotNull);
      expect(CatalogValidator.fieldKey('MarriageHall'), isNotNull);
      expect(CatalogValidator.fieldKey('_leading'), isNotNull);
      expect(CatalogValidator.fieldKey('trailing_'), isNotNull);
      expect(
        CatalogValidator.fieldKey('a' * (CatalogValidator.maxKeyLength + 1)),
        isNotNull,
      );
    });

    test('rejects an id already used anywhere in the document', () {
      final content = CatalogContent.defaults;
      final taken = content.facilityTypes.first.sections.first.key;

      expect(
        CatalogValidator.fieldKey(taken, existing: content),
        isNotNull,
        reason: 'ids must be unique across all three levels',
      );
      expect(
        CatalogValidator.fieldKey(taken, existing: content, currentKey: taken),
        isNull,
        reason: 'editing a node keeps its own id valid',
      );
      expect(
        CatalogValidator.fieldKey('brand_new_key', existing: content),
        isNull,
      );
    });
  });

  group('text validation', () {
    test('a title is required and length-capped', () {
      expect(CatalogValidator.fieldTitle('Function Halls'), isNull);
      expect(CatalogValidator.fieldTitle(''), isNotNull);
      expect(CatalogValidator.fieldTitle('   '), isNotNull);
      expect(
        CatalogValidator.fieldTitle(
            'a' * (CatalogValidator.maxTitleLength + 1)),
        isNotNull,
      );
    });

    test('a translation may be empty but is still length-capped', () {
      expect(CatalogValidator.fieldTranslation(''), isNull);
      expect(CatalogValidator.fieldTranslation(null), isNull);
      expect(CatalogValidator.fieldTranslation('some translated text'), isNull);
      expect(
        CatalogValidator.fieldTranslation(
            'a' * (CatalogValidator.maxTitleLength + 1)),
        isNotNull,
      );
    });

    test('control and bidi characters are rejected', () {
      // Written as escapes on purpose: these characters are invisible in a
      // diff, and a bidi override can make stored text render as something
      // other than what it actually says.
      expect(CatalogValidator.fieldTitle('Halls\u0007'), isNotNull);
      expect(CatalogValidator.fieldTitle('Halls\u202E'), isNotNull);
      expect(CatalogValidator.fieldTitle('Halls\u2066x\u2069'), isNotNull);
      expect(CatalogValidator.fieldDescription('Nice\u0000venue'), isNotNull);
      expect(CatalogValidator.fieldTranslation('t\u202Eext'), isNotNull);
    });

    test('ordinary punctuation and non-Latin scripts are accepted', () {
      expect(CatalogValidator.fieldTitle('Party Halls & Lawns'), isNull);
      expect(CatalogValidator.fieldTitle('PG / Hostels'), isNull);
      expect(CatalogValidator.fieldTitle('Cafe - rooftop'), isNull);
      expect(CatalogValidator.fieldTitle('\u0C2B\u0C02'), isNull);
    });

    test('markup is accepted as literal text, not treated as code', () {
      // Content is rendered through Text widgets, never as HTML, so a tag is
      // inert. Rejecting it would only stop an admin writing about "<b>".
      expect(CatalogValidator.fieldTitle('<b>Halls</b>'), isNull);
      expect(
        CatalogValidator.fieldDescription('Use <script> carefully'),
        isNull,
      );
    });

    test('descriptions are optional and length-capped', () {
      expect(CatalogValidator.fieldDescription(''), isNull);
      expect(CatalogValidator.fieldDescription(null), isNull);
      expect(
        CatalogValidator.fieldDescription(
            'a' * (CatalogValidator.maxDescriptionLength + 1)),
        isNotNull,
      );
    });
  });

  group('order, media and icon validation', () {
    test('order must be a whole number in range', () {
      expect(CatalogValidator.fieldOrder('0'), isNull);
      expect(CatalogValidator.fieldOrder('120'), isNull);
      expect(CatalogValidator.fieldOrder(''), isNotNull);
      expect(CatalogValidator.fieldOrder('abc'), isNotNull);
      expect(CatalogValidator.fieldOrder('1.5'), isNotNull);
      expect(CatalogValidator.fieldOrder('-1'), isNotNull);
      expect(
        CatalogValidator.fieldOrder('${CatalogValidator.maxOrder + 1}'),
        isNotNull,
      );
    });

    test('media must be empty or an absolute http(s) url', () {
      expect(CatalogValidator.fieldMediaUrl(''), isNull);
      expect(CatalogValidator.fieldMediaUrl(null), isNull);
      expect(
        CatalogValidator.fieldMediaUrl('https://cdn.example/a.jpg'),
        isNull,
      );
      expect(CatalogValidator.fieldMediaUrl('javascript:alert(1)'), isNotNull);
      expect(CatalogValidator.fieldMediaUrl('file:///etc/passwd'), isNotNull);
      expect(CatalogValidator.fieldMediaUrl('/relative/a.jpg'), isNotNull);
      expect(CatalogValidator.fieldMediaUrl('not a url'), isNotNull);
    });

    test('icons must come from the compiled-in registry', () {
      expect(CatalogValidator.fieldIcon('hall'), isNull);
      expect(CatalogValidator.fieldIcon(''), isNull);
      expect(CatalogValidator.fieldIcon('no_such_icon'), isNotNull);
    });
  });

  group('whole-document validation', () {
    test('the shipped defaults publish cleanly', () {
      final issues = CatalogValidator.validate(CatalogContent.defaults);
      expect(issues.where((i) => i.isError), isEmpty,
          reason: issues.map((i) => i.message).join('; '));
      expect(CatalogValidator.canPublish(CatalogContent.defaults), isTrue);
    });

    test('the same id may appear under different kinds', () {
      // The shipped catalogue depends on this: `sports` is a deployed
      // `venue_categories.parent_section` value (so a facility type key) and
      // also a category slug (so a subsection key). The levels are separate
      // namespaces, so reusing a string across them is not a collision.
      final content = CatalogContent.defaults;
      final typeKeys = content.facilityTypes.map((t) => t.key).toSet();
      final subsectionKeys = content.facilityTypes
          .expand((t) => t.sections)
          .expand((s) => s.subsections)
          .map((s) => s.key)
          .toSet();

      expect(typeKeys.intersection(subsectionKeys), isNotEmpty,
          reason: 'the shipped catalogue reuses at least one id across kinds');
      expect(CatalogValidator.canPublish(content), isTrue);
    });

    test('a duplicate id within one kind is still an error', () {
      const content = CatalogContent([
        CatalogFacilityType(key: 'dupe', title: CmsLocalizedText(base: 'One')),
        CatalogFacilityType(key: 'dupe', title: CmsLocalizedText(base: 'Two')),
      ]);

      final issues = CatalogValidator.validate(content);
      expect(
        issues.any((i) => i.isError && i.field == 'key' && i.nodeKey == 'dupe'),
        isTrue,
      );
      expect(CatalogValidator.canPublish(content), isFalse);
    });

    test('a catalogue with nothing visible cannot be published', () {
      var content = CatalogContent.defaults;
      for (final type in CatalogContent.defaults.facilityTypes) {
        content = content.upsertFacilityType(type.copyWith(enabled: false));
      }
      expect(CatalogValidator.canPublish(content), isFalse);
      expect(CatalogValidator.validate(content).any((i) => i.isError), isTrue);
    });

    test('a blank title blocks publishing and names the node', () {
      final key = CatalogContent.defaults.facilityTypes.first.key;
      final content = CatalogContent.defaults.upsertFacilityType(
        CatalogContent.defaults
            .facilityTypeFor(key)!
            .copyWith(title: CmsLocalizedText.empty),
      );

      expect(CatalogValidator.canPublish(content), isFalse);
      final errors =
          CatalogValidator.validate(content).where((i) => i.isError).toList();
      expect(errors.any((i) => i.nodeKey == key && i.field == 'title'), isTrue);
    });

    test('a section with no linked slugs warns but does not block', () {
      final typeKey = CatalogContent.defaults.facilityTypes.first.key;
      final section =
          CatalogContent.defaults.facilityTypeFor(typeKey)!.sections.first;
      final content = CatalogContent.defaults.upsertSection(
        typeKey,
        section.copyWith(searchAliases: const []),
      );

      final issues = CatalogValidator.validate(content);
      expect(
        issues.any((i) =>
            !i.isError &&
            i.nodeKey == section.key &&
            i.field == 'search_aliases'),
        isTrue,
      );
      expect(CatalogValidator.canPublish(content), isTrue,
          reason: 'warnings must not block an admin mid-edit');
    });

    test('a facility type with no sections warns but does not block', () {
      final content = CatalogContent.defaults.upsertFacilityType(
        const CatalogFacilityType(
          key: 'stays',
          title: CmsLocalizedText(base: 'Stays'),
        ),
      );
      final issues = CatalogValidator.validate(content);
      expect(issues.any((i) => !i.isError && i.nodeKey == 'stays'), isTrue);
      expect(CatalogValidator.canPublish(content), isTrue);
    });
  });

  group('localized content validation', () {
    test('accepts locale overrides and rejects malformed locale keys', () {
      final base = CatalogContent.defaults.facilityTypes.first;
      final valid = base.copyWith(
        title: base.title.withLanguage('te', 'వేదిక'),
        description: base.description.withLanguage('hi', 'विवरण'),
      );
      expect(
          CatalogValidator.validate(
            CatalogContent([valid]),
          ).where((i) => i.isError),
          isEmpty);

      final invalid = base.copyWith(
        title: base.title.withLanguage('not a locale', 'Bad'),
      );
      expect(
        CatalogValidator.validate(CatalogContent([invalid]))
            .any((i) => i.field == 'translations'),
        isTrue,
      );
    });

    test('missing translations resolve to the default text', () {
      const text =
          CmsLocalizedText(base: 'English', overrides: {'te': 'తెలుగు'});
      expect(text.resolve('fr'), 'English');
      expect(text.resolve('te'), 'తెలుగు');
      expect(const CmsLocalizedText().resolveOr('te', 'Fallback'), 'Fallback');
    });
  });
}
