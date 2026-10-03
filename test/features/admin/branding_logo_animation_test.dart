import 'package:bookmyspace/core/widgets/bookmyspace_brand.dart';
import 'package:bookmyspace/features/admin/presentation/app_branding_providers.dart';
import 'package:bookmyspace/features/admin/presentation/branding_revisions.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_app_studio_screen.dart';
import 'package:bookmyspace/features/admin/presentation/widgets/brand_loading_indicator.dart';
import 'package:bookmyspace/features/cms/domain/app_element_registry.dart';
import 'package:bookmyspace/features/cms/domain/ui_element_override.dart';
import 'package:bookmyspace/features/cms/presentation/ui_element_override_providers.dart';
import 'package:bookmyspace/features/cms/presentation/widgets/live_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the global `module_feature_configs` rows.
class _FakeStore implements BrandingSectionStore {
  _FakeStore([Map<String, Map<String, dynamic>>? rows]) : rows = rows ?? {};

  final Map<String, Map<String, dynamic>> rows;

  @override
  Future<Map<String, dynamic>> loadSection(String section) async =>
      Map<String, dynamic>.from(rows[section] ?? const {});

  @override
  Future<void> saveSection(String section, Map<String, dynamic> values) async {
    rows[section] = Map<String, dynamic>.from(values);
  }
}

/// The loading spinner animates forever, so pumpAndSettle never settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _logo = 'https://cdn.example.com/cms/new-logo.png';
const _gif = 'https://cdn.example.com/cms/loader.gif';

void main() {
  group('registry', () {
    test('logo and loading animation have stable global-branding keys', () {
      final logo = AppElementRegistry.findByKey(
        AppElementRegistry.brandLogoKey,
      );
      final dark = AppElementRegistry.findByKey(
        AppElementRegistry.brandLogoDarkKey,
      );
      final anim = AppElementRegistry.findByKey(
        AppElementRegistry.loadingAnimationKey,
      );
      expect(AppElementRegistry.brandLogoKey, 'branding.logo_url');
      expect(
        AppElementRegistry.loadingAnimationKey,
        'branding.loading_animation',
      );
      for (final def in [logo, dark, anim]) {
        expect(def, isNotNull);
        expect(def!.isGlobalBranding, isTrue);
      }
      expect(logo!.elementType, UiElementType.image);
      expect(anim!.elementType, UiElementType.animation);
    });

    test('registry keys are unique and only branding rows are global', () {
      final keys = AppElementRegistry.all.map((e) => e.qualifiedKey).toList();
      expect(keys.toSet().length, keys.length);
      for (final def in AppElementRegistry.all) {
        expect(
          def.isGlobalBranding,
          def.screenKey == 'branding',
          reason: def.qualifiedKey,
        );
      }
    });
  });

  group('AppBranding', () {
    test('round-trips the loading animation asset', () {
      final b = AppBranding.fromMap({
        'logo_url': _logo,
        'animation_asset_url': ' $_gif ',
        'animation_enabled': false,
      });
      expect(b.animationAssetUrl, _gif);
      expect(b.animationEnabled, isFalse);
      expect(AppBranding.fromMap(b.toMap()).animationAssetUrl, _gif);
      expect(AppBranding.defaults.animationAssetUrl, isNull);
    });
  });

  group('BrandingRevisionService', () {
    late _FakeStore store;
    late BrandingRevisionService service;
    var tick = 0;

    setUp(() {
      store = _FakeStore({'branding': AppBranding.defaults.toMap()});
      tick = 0;
      service = BrandingRevisionService(
        store,
        clock: () => DateTime.utc(2026, 10, 3, 10, tick++),
      );
    });

    test(
      'draft never touches the live row and is cleared on publish',
      () async {
        await service.saveDraft({'logo_url': _logo});
        expect(store.rows['branding']!['logo_url'], isNull);
        expect((await service.loadDraft())!.branding.logoUrl, _logo);

        await service.publish({'logo_url': _logo});
        expect(store.rows['branding']!['logo_url'], _logo);
        expect(await service.loadDraft(), isNull);
      },
    );

    test('first publish keeps the previous live version for undo', () async {
      await service.publish({'logo_url': _logo, 'animation_asset_url': _gif});
      final history = await service.loadHistory();
      expect(history, hasLength(2));
      expect(history.first.branding.logoUrl, _logo);
      expect(history.last.branding.logoUrl, isNull);

      final undone = await service.undoLastPublish();
      expect(undone!['logo_url'], isNull);
      expect(store.rows['branding']!['logo_url'], isNull);
      expect(store.rows['branding']!['animation_asset_url'], isNull);
      expect((await service.loadHistory()).first.label, 'Undo');
    });

    test('restore re-publishes a snapshot; history is bounded', () async {
      for (var i = 0; i < 30; i++) {
        await service.publish({'app_name': 'Name $i'});
      }
      final history = await service.loadHistory();
      expect(history, hasLength(BrandingRevisionService.maxHistory));
      await service.restore(history[5]);
      expect(store.rows['branding']!['app_name'], 'Name 24');
    });

    test('invalid values are normalised before publishing', () async {
      await service.publish({
        'animation_color': 'not-a-colour',
        'animation_thickness': 99,
      });
      expect(store.rows['branding']!['animation_color'], isNull);
      expect(
        store.rows['branding']!['animation_thickness'],
        AppBranding.maxAnimationThickness,
      );
    });
  });

  group('runtime widgets', () {
    testWidgets('loading indicator: spinner, asset, disabled', (tester) async {
      Future<void> pump(AppBranding b) => tester.pumpWidget(
        MaterialApp(
          home: Center(child: BrandLoadingIndicator(branding: b)),
        ),
      );

      await pump(AppBranding.defaults);
      expect(find.byKey(BrandLoadingIndicator.spinnerKey), findsOneWidget);

      await pump(const AppBranding(animationAssetUrl: _gif));
      expect(find.byKey(BrandLoadingIndicator.assetKey), findsOneWidget);
      expect(find.byKey(BrandLoadingIndicator.spinnerKey), findsNothing);

      await pump(
        const AppBranding(animationEnabled: false, animationAssetUrl: _gif),
      );
      expect(find.byKey(BrandLoadingIndicator.spinnerKey), findsNothing);
      expect(find.byKey(BrandLoadingIndicator.assetKey), findsNothing);
    });

    testWidgets('live logo widgets read the single branding provider', (
      tester,
    ) async {
      Future<void> pump(AppBranding b) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [appBrandingProvider.overrideWith((ref) async => b)],
            child: const MaterialApp(
              home: Column(
                children: [
                  LiveBrandMark(size: 40),
                  LivePulsingBrandMark(size: 40),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump(const AppBranding(logoUrl: _logo, animationEnabled: false));
      // Live marks carry the admin URL (any extra marks are the bundled
      // placeholder AppNetworkImage shows while the URL loads).
      final marks = tester
          .widgetList<BookMySpaceMark>(find.byType(BookMySpaceMark))
          .where((m) => m.logoUrlOverride != null);
      expect(marks, hasLength(2));
      expect(marks.every((m) => m.logoUrlOverride == _logo), isTrue);
      expect(
        tester.widget<PulsingBrandMark>(find.byType(PulsingBrandMark)).animate,
        isFalse,
      );

      await pump(AppBranding.defaults);
      expect(
        tester
            .widgetList<BookMySpaceMark>(find.byType(BookMySpaceMark))
            .every((m) => m.logoUrlOverride == null),
        isTrue,
      );
      expect(find.byType(Image), findsNWidgets(2)); // bundled asset
    });
  });

  group('App Studio → Global Branding', () {
    late _FakeStore store;

    Future<void> openBranding(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appBrandingProvider.overrideWith(
              (ref) async => AppBranding.fromMap(store.rows['branding'] ?? {}),
            ),
            brandingRevisionServiceProvider.overrideWithValue(
              BrandingRevisionService(store),
            ),
            adminUiElementOverridesProvider.overrideWith(
              (ref, key) async => <UiElementOverride>[],
            ),
          ],
          child: const MaterialApp(home: AdminAppStudioScreen()),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Global Branding'));
      await _settle(tester);
    }

    setUp(() => store = _FakeStore({'branding': AppBranding.defaults.toMap()}));

    testWidgets('draft → preview → publish → undo for logo + animation', (
      tester,
    ) async {
      await openBranding(tester);

      await tester.enterText(
        find.byKey(const ValueKey('branding-logo-light')),
        _logo,
      );
      await tester.enterText(
        find.byKey(const ValueKey('branding-animation-asset')),
        _gif,
      );
      await tester.pump();

      // Preview shows the unpublished values; live row untouched.
      final preview = tester.widget<BookMySpaceMark>(
        find.byKey(const ValueKey('branding-preview-logo-light')),
      );
      expect(preview.logoUrlOverride, _logo);
      expect(find.byKey(BrandLoadingIndicator.assetKey), findsOneWidget);
      expect(store.rows['branding']!['logo_url'], isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey('branding-save-draft')),
      );
      await tester.tap(find.byKey(const ValueKey('branding-save-draft')));
      await _settle(tester);
      expect(
        (store.rows['branding_draft']!['values'] as Map)['logo_url'],
        _logo,
      );
      expect(store.rows['branding']!['logo_url'], isNull);
      expect(
        find.byKey(const ValueKey('branding-draft-banner')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('branding-publish')),
      );
      await tester.tap(find.byKey(const ValueKey('branding-publish')));
      await _settle(tester);
      expect(store.rows['branding']!['logo_url'], _logo);
      expect(store.rows['branding']!['animation_asset_url'], _gif);
      expect(store.rows['branding_draft'], isEmpty);
      expect(find.byKey(const ValueKey('branding-draft-banner')), findsNothing);
      expect(find.byKey(const ValueKey('branding-history-1')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('branding-undo')));
      await tester.tap(find.byKey(const ValueKey('branding-undo')));
      await _settle(tester);
      expect(store.rows['branding']!['logo_url'], isNull);
      expect(store.rows['branding']!['animation_asset_url'], isNull);
    });

    testWidgets('reset logo / reset animation publish bundled defaults', (
      tester,
    ) async {
      store.rows['branding'] = const AppBranding(
        logoUrl: _logo,
        animationEnabled: false,
        animationAssetUrl: _gif,
      ).toMap();
      await openBranding(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('branding-reset-logo')),
      );
      await tester.tap(find.byKey(const ValueKey('branding-reset-logo')));
      await _settle(tester);
      expect(store.rows['branding']!['logo_url'], isNull);
      expect(store.rows['branding']!['animation_enabled'], isFalse);

      await tester.ensureVisible(
        find.byKey(const ValueKey('branding-reset-animation')),
      );
      await tester.tap(find.byKey(const ValueKey('branding-reset-animation')));
      await _settle(tester);
      expect(store.rows['branding']!['animation_enabled'], isTrue);
      expect(store.rows['branding']!['animation_asset_url'], isNull);
      expect(store.rows['branding']!['animation_color'], isNull);

      final labels = BrandingRevisionService.parseHistory(
        store.rows['branding_history']!,
      ).map((e) => e.label);
      expect(labels.take(2), ['Reset animation', 'Reset logo']);
    });

    testWidgets('branding registry elements route to Global Branding', (
      tester,
    ) async {
      await openBranding(tester);
      await tester.tap(find.text('UI Elements'));
      await _settle(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await _settle(tester);
      await tester.tap(find.textContaining('BRANDING (').last);
      await _settle(tester);
      expect(find.textContaining('branding.loading_animation'), findsOneWidget);
      await tester.tap(find.text('Edit in Global Branding').first);
      await _settle(tester);
      expect(find.byKey(const ValueKey('branding-publish')), findsOneWidget);
    });
  });
}
