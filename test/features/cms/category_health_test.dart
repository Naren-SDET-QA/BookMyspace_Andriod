import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/domain/category_health.dart';
import 'package:bookmyspace/features/cms/domain/cms_localized_text.dart';
import 'package:bookmyspace/features/cms/presentation/catalog_content_providers.dart';
import 'package:bookmyspace/features/cms/presentation/screens/admin_catalog_screen.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag_repository.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FlagRepo implements FeatureFlagRepository {
  _FlagRepo(this.content);
  final CatalogContent content;

  @override
  Future<List<FeatureFlag>> listFlags() async => [
    FeatureFlag(
      key: catalogContentFlagKey,
      enabled: true,
      platforms: const ['ios', 'android', 'web'],
      config: content.toJson(),
    ),
  ];

  @override
  Future<FeatureFlag> saveFlag({
    required String key,
    required bool enabled,
    required List<String> platforms,
    required Map<String, dynamic> config,
  }) async => FeatureFlag(
    key: key,
    enabled: enabled,
    platforms: platforms,
    config: config,
  );
}

class _StatsRepo implements CategoryListingStatsRepository {
  const _StatsRepo(this.stats);
  final Map<String, CategoryListingStats> stats;
  @override
  Future<Map<String, CategoryListingStats>> statsBySlug() async => stats;
}

CatalogContent _content() => const CatalogContent([
  CatalogFacilityType(
    key: 'zeta_venues',
    title: CmsLocalizedText(base: 'Zeta Venues'),
    sections: [
      CatalogSection(
        key: 'zeta_halls',
        title: CmsLocalizedText(base: 'Zeta Halls'),
        subsections: [
          CatalogSubsection(
            key: 'zeta_marriage',
            title: CmsLocalizedText(base: 'Zeta Marriage'),
            aliasSlugs: ['zeta-marriage'],
          ),
          CatalogSubsection(
            key: 'zeta_rooftops',
            title: CmsLocalizedText(base: 'Zeta Rooftops'),
          ),
          CatalogSubsection(key: 'zeta_untitled'),
        ],
      ),
    ],
  ),
]);

Finder _healthScrollable() => find.descendant(
  of: find.byKey(AdminCatalogScreen.healthListKey),
  matching: find.byType(Scrollable),
);

void main() {
  group('CategoryHealthEngine.score', () {
    test('healthy category keeps 100', () {
      final r = CategoryHealthEngine.score(
        title: 'Zeta Halls',
        slug: 'halls',
        enabled: true,
        stats: const CategoryListingStats(listings: 3, withImages: 3),
      );
      expect(r.score, 100);
      expect(r.issues, isEmpty);
      expect(
        CategoryHealthStatus.forScore(r.score),
        CategoryHealthStatus.healthy,
      );
    });

    test('applies each penalty', () {
      expect(
        CategoryHealthEngine.score(title: ' ', slug: 'x', enabled: false).score,
        70,
      );
      expect(
        CategoryHealthEngine.score(
          title: 'A',
          slug: 'a',
          enabled: true,
          stats: const CategoryListingStats(),
        ).score,
        75,
      );
      final images = CategoryHealthEngine.score(
        title: 'A',
        slug: 'a',
        enabled: true,
        stats: const CategoryListingStats(listings: 4, withImages: 1),
      );
      expect(images.score, 85);
      expect(images.issues.single.message, '3 of 4 listings have no images');
      // Hidden empty category is not penalised for being empty.
      expect(
        CategoryHealthEngine.score(
          title: 'A',
          slug: 'a',
          enabled: false,
          stats: const CategoryListingStats(),
        ).score,
        100,
      );
      final worst = CategoryHealthEngine.score(
        title: '',
        slug: '',
        enabled: true,
        stats: const CategoryListingStats(),
      );
      expect(worst.score, 45);
      expect(
        CategoryHealthStatus.forScore(worst.score),
        CategoryHealthStatus.critical,
      );
    });

    test('status thresholds', () {
      expect(CategoryHealthStatus.forScore(80), CategoryHealthStatus.healthy);
      expect(
        CategoryHealthStatus.forScore(79),
        CategoryHealthStatus.needsAttention,
      );
      expect(
        CategoryHealthStatus.forScore(50),
        CategoryHealthStatus.needsAttention,
      );
      expect(CategoryHealthStatus.forScore(49), CategoryHealthStatus.critical);
    });

    test('unknown stats skip listing rules', () {
      final r = CategoryHealthEngine.score(
        title: 'A',
        slug: 'a',
        enabled: true,
      );
      expect(r.score, 100);
    });
  });

  test('evaluate aggregates aliases and sorts worst first', () {
    final health = CategoryHealthEngine.evaluate(
      _content(),
      statsBySlug: const {
        'zeta_marriage': CategoryListingStats(listings: 2, withImages: 2),
        'zeta-marriage': CategoryListingStats(listings: 1, withImages: 0),
      },
    );
    final byKey = {for (final h in health) h.key: h};
    expect(byKey['zeta_marriage']!.stats!.listings, 3);
    expect(byKey['zeta_marriage']!.score, 85);
    expect(byKey['zeta_rooftops']!.score, 75);
    // No title (-30) and no listings (-25).
    expect(byKey['zeta_untitled']!.score, 45);
    expect(byKey['zeta_halls']!.stats!.listings, 3);
    expect(health.first.score, lessThanOrEqualTo(health.last.score));
  });

  group('admin catalogue health view', () {
    Widget app() => ProviderScope(
      overrides: [
        featureFlagRepositoryProvider.overrideWithValue(_FlagRepo(_content())),
        categoryListingStatsRepositoryProvider.overrideWithValue(
          const _StatsRepo({
            'zeta_marriage': CategoryListingStats(listings: 2, withImages: 2),
          }),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminCatalogScreen(),
      ),
    );

    testWidgets('needs-healing filter and disable action', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AdminCatalogScreen.healthButtonKey));
      await tester.pumpAndSettle();

      final disable = find.byKey(
        AdminCatalogScreen.healthDisableKey('zeta_rooftops'),
      );
      await tester.scrollUntilVisible(
        disable,
        300,
        scrollable: _healthScrollable(),
      );
      expect(find.text('Zeta Rooftops'), findsOneWidget);
      await tester.tap(disable);
      await tester.pumpAndSettle();
      expect(find.textContaining('hidden in your draft'), findsOneWidget);
      // The draft is now dirty, so Publish is enabled.
      final publish = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Publish'),
      );
      expect(publish.onPressed, isNotNull);

      // Healthy categories only show once the filter is cleared.
      await tester.tap(find.byKey(AdminCatalogScreen.healthButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AdminCatalogScreen.needsHealingKey));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Zeta Marriage'),
        300,
        scrollable: _healthScrollable(),
      );
      expect(find.text('Zeta Marriage'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('edit action opens the node editor', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AdminCatalogScreen.healthButtonKey));
      await tester.pumpAndSettle();
      final edit = find.byKey(
        AdminCatalogScreen.healthEditKey('zeta_untitled'),
      );
      await tester.scrollUntilVisible(
        edit,
        300,
        scrollable: _healthScrollable(),
      );
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Back to catalogue'), findsOneWidget);
    });
  });
}
