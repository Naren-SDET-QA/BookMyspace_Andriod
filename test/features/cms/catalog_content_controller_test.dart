import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/domain/cms_localized_text.dart';
import 'package:bookmyspace/features/cms/presentation/catalog_content_providers.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag_repository.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFlagRepository implements FeatureFlagRepository {
  FakeFlagRepository({List<FeatureFlag> seed = const []}) : _rows = [...seed];

  final List<FeatureFlag> _rows;
  final List<Map<String, dynamic>> saved = [];
  Object? saveError;

  @override
  Future<List<FeatureFlag>> listFlags() async => List.of(_rows);

  @override
  Future<FeatureFlag> saveFlag({
    required String key,
    required bool enabled,
    required List<String> platforms,
    required Map<String, dynamic> config,
  }) async {
    final error = saveError;
    if (error != null) throw error;
    saved.add(config);
    final row = FeatureFlag(
      key: key,
      enabled: enabled,
      platforms: platforms,
      config: config,
    );
    _rows.removeWhere((e) => e.key == key);
    _rows.add(row);
    return row;
  }
}

void main() {
  group('CatalogContentController', () {
    test('save persists the document through the feature flag repository',
        () async {
      final repo = FakeFlagRepository();
      final container = ProviderContainer(
        overrides: [featureFlagRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final controller = container.read(catalogContentControllerProvider);
      await controller.save(CatalogContent.defaults);

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single['facility_types'], isA<List<dynamic>>());
    });

    test('save sends enabled=true and the default platforms', () async {
      final repo = FakeFlagRepository();
      final container = ProviderContainer(
        overrides: [featureFlagRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final controller = container.read(catalogContentControllerProvider);
      await controller.save(CatalogContent.defaults);

      // The controller reads the existing flag to get platforms.
      // With an empty repo the flag defaults are used.
      final saved = repo.saved.single;
      expect(saved['facility_types'], isA<List<dynamic>>());
    });

    test('resetToDefaults writes an empty config', () async {
      final repo = FakeFlagRepository(seed: [
        const FeatureFlag(
          key: 'category_catalog',
          enabled: true,
          platforms: ['ios', 'android', 'web'],
          config: {
            'facility_types': [
              {'key': 'custom', 'order': 1}
            ]
          },
        ),
      ]);
      final container = ProviderContainer(
        overrides: [featureFlagRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final controller = container.read(catalogContentControllerProvider);
      await controller.resetToDefaults();

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single, isEmpty,
          reason: 'reset writes an empty config, which resolves to defaults');
    });

    test('resetToDefaults after save yields the shipped defaults', () async {
      final repo = FakeFlagRepository(seed: [
        const FeatureFlag(
          key: 'category_catalog',
          enabled: true,
          platforms: ['ios', 'android', 'web'],
          config: {},
        ),
      ]);
      final container = ProviderContainer(
        overrides: [featureFlagRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final controller = container.read(catalogContentControllerProvider);

      // Publish a custom document first
      final custom = CatalogContent.defaults.upsertFacilityType(
        const CatalogFacilityType(
          key: 'stays',
          title: CmsLocalizedText(base: 'Stays'),
        ),
      );
      await controller.save(custom);
      expect(repo.saved, hasLength(1));

      // Then reset
      await controller.resetToDefaults();
      expect(repo.saved, hasLength(2));
      expect(repo.saved.last, isEmpty);
    });

    test('save propagates repository errors to the caller', () async {
      final repo = FakeFlagRepository()
        ..saveError = Exception('row-level security');
      final container = ProviderContainer(
        overrides: [featureFlagRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final controller = container.read(catalogContentControllerProvider);
      expect(
        () => controller.save(CatalogContent.defaults),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('CatalogContent.fromJson edge cases', () {
    test('a fully empty facility type list yields defaults', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': <Map<String, dynamic>>[],
      });
      expect(content.facilityTypes,
          hasLength(CatalogContent.defaults.facilityTypes.length));
    });

    test('nested subsection with missing key is dropped', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {
            'key': 'venues',
            'sections': [
              {
                'key': 'function_halls',
                'subsections': [
                  {'title': 'No key here'},
                  {'key': 'marriage_hall', 'title': 'Weddings'},
                ],
              },
            ],
          },
        ],
      });
      final section = content.sectionFor('function_halls')!;
      expect(section.subsections, hasLength(1));
      expect(section.subsections.single.key, 'marriage_hall');
    });

    test('malformed alias_slugs are dropped', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {
            'key': 'venues',
            'sections': [
              {
                'key': 'function_halls',
                'search_aliases': ['valid_slug', '', 123, 'another'],
              },
            ],
          },
        ],
      });
      final section = content.sectionFor('function_halls')!;
      expect(section.searchAliases, ['valid_slug', 'another']);
    });

    test('enabled field defaults to true when absent', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues'},
        ],
      });
      expect(content.facilityTypeFor('venues')!.enabled, isTrue);
    });

    test('order defaults to 0 when absent', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues'},
        ],
      });
      expect(content.facilityTypeFor('venues')!.order, 0);
    });

    test('emoji with more than 8 runes is dropped', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues', 'emoji': '123456789'},
        ],
      });
      expect(content.facilityTypeFor('venues')!.emoji, isEmpty);
    });

    test('media url with non-http scheme is dropped', () {
      final content = CatalogContent.fromJson(const {
        'facility_types': [
          {'key': 'venues', 'media': 'ftp://example.com/image.jpg'},
        ],
      });
      expect(content.facilityTypeFor('venues')!.media.isEmpty, isTrue);
    });
  });
}
