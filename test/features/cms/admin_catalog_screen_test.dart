import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/presentation/screens/admin_catalog_screen.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag_repository.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for the flag store.
///
/// Recording the exact payload is the point: this is the layer where the
/// `unsupported_module` defect lived undetected, because nothing asserted on
/// what a write actually sends.
class FakeFlagRepository implements FeatureFlagRepository {
  FakeFlagRepository({List<FeatureFlag> seed = const []}) : _rows = [...seed];

  final List<FeatureFlag> _rows;

  /// Every config published, oldest first.
  final List<Map<String, dynamic>> saved = [];

  /// When set, `saveFlag` throws it, standing in for an RLS or validator
  /// rejection.
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
    _rows.removeWhere((existing) => existing.key == key);
    _rows.add(row);
    return row;
  }
}

Widget _app(FakeFlagRepository repo) {
  return ProviderScope(
    overrides: [featureFlagRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AdminCatalogScreen(),
    ),
  );
}

Finder _publishButton() => find.widgetWithText(FilledButton, 'Publish');

bool _publishEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_publishButton()).onPressed != null;

/// Opens the first facility type and starts editing it.
Future<void> _editFirstFacilityType(WidgetTester tester) async {
  final label = CatalogContent.defaults.facilityTypes.first.title.base;
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the shipped catalogue when nothing is published',
      (tester) async {
    await tester.pumpWidget(_app(FakeFlagRepository()));
    await tester.pumpAndSettle();

    for (final type in CatalogContent.defaults.facilityTypes) {
      expect(find.text(type.title.base).first, findsOneWidget,
          reason: 'missing ${type.key}');
    }
    expect(find.text('Add facility type'), findsOneWidget);
  });

  testWidgets('publish is disabled until something changes', (tester) async {
    await tester.pumpWidget(_app(FakeFlagRepository()));
    await tester.pumpAndSettle();

    expect(_publishEnabled(tester), isFalse);
  });

  testWidgets('editing a title enables publish and sends the edit',
      (tester) async {
    final repo = FakeFlagRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _editFirstFacilityType(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Celebrations');
    await tester.pumpAndSettle();
    expect(_publishEnabled(tester), isTrue);

    await tester.tap(_publishButton());
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    final published = CatalogContent.fromJson(repo.saved.single);
    final key = CatalogContent.defaults.facilityTypes.first.key;
    expect(published.facilityTypeFor(key)!.title.base, 'Celebrations');
  });

  testWidgets('a published payload is a facility_types document',
      (tester) async {
    final repo = FakeFlagRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _editFirstFacilityType(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Celebrations');
    await tester.pumpAndSettle();
    await tester.tap(_publishButton());
    await tester.pumpAndSettle();

    // The database validator rejects anything whose `facility_types` is not an
    // array, so the client must never send another shape.
    expect(repo.saved.single['facility_types'], isA<List<dynamic>>());
  });

  testWidgets('a blank title blocks publishing and explains why',
      (tester) async {
    final repo = FakeFlagRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _editFirstFacilityType(tester);
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.pumpAndSettle();

    await tester.tap(_publishButton());
    await tester.pumpAndSettle();

    expect(repo.saved, isEmpty, reason: 'nothing may reach the backend');
    expect(find.text('Fix these before publishing'), findsOneWidget);
  });

  testWidgets('a rejected publish keeps the draft instead of losing work',
      (tester) async {
    final repo = FakeFlagRepository()
      ..saveError = Exception('row-level security');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _editFirstFacilityType(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Celebrations');
    await tester.pumpAndSettle();

    await tester.tap(_publishButton());
    await tester.pumpAndSettle();

    expect(_publishEnabled(tester), isTrue,
        reason: 'the draft must survive a failed publish so it can be retried');
    expect(find.textContaining('Could not publish'), findsOneWidget);
  });

  testWidgets('hiding a facility type keeps it in the tree but out of preview',
      (tester) async {
    // The editor is a lazy ListView: only the fields that fit the viewport are
    // built. Give the test a tall window so the visibility switch exists
    // without depending on scroll timing.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeFlagRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await _editFirstFacilityType(tester);

    await tester.tap(find.text('Visible to customers'));
    await tester.pumpAndSettle();
    await tester.tap(_publishButton());
    await tester.pumpAndSettle();

    final published = CatalogContent.fromJson(repo.saved.single);
    final key = CatalogContent.defaults.facilityTypes.first.key;
    expect(published.facilityTypeFor(key), isNotNull,
        reason: 'hidden content is kept, not deleted');
    expect(published.facilityTypeFor(key)!.enabled, isFalse);
    expect(published.visible.any((t) => t.key == key), isFalse);
  });

  testWidgets('a shipped facility type offers no delete button',
      (tester) async {
    // Same lazy-list caveat as above: the shipped-type explanation sits below
    // the first screenful of editor fields.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(FakeFlagRepository()));
    await tester.pumpAndSettle();

    await _editFirstFacilityType(tester);

    expect(find.textContaining('Delete this'), findsNothing);
    expect(find.textContaining('built into the app'), findsOneWidget);
  });

  testWidgets('a malformed stored document falls back to the shipped catalogue',
      (tester) async {
    final repo = FakeFlagRepository(seed: [
      const FeatureFlag(
        key: 'category_catalog',
        enabled: true,
        platforms: ['ios', 'android', 'web'],
        config: {'facility_types': 'not-an-array'},
      ),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    for (final type in CatalogContent.defaults.facilityTypes) {
      expect(find.text(type.title.base).first, findsOneWidget);
    }
  });

  testWidgets('the wide layout shows tree, editor and preview together',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(FakeFlagRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Add facility type'), findsOneWidget);
  });

  testWidgets('adding a new facility type via the dialog', (tester) async {
    final repo = FakeFlagRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add facility type'));
    await tester.pumpAndSettle();

    expect(find.text('New facility type'), findsOneWidget);

    // Enter title and key
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Stays',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Id'),
      'stays',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // The new type should appear in the tree
    expect(find.text('Stays').first, findsOneWidget);
    expect(_publishEnabled(tester), isTrue);

    // Publish and verify it is in the saved document
    await tester.tap(_publishButton());
    await tester.pumpAndSettle();

    final published = CatalogContent.fromJson(repo.saved.single);
    expect(published.facilityTypeFor('stays'), isNotNull);
    expect(published.facilityTypeFor('stays')!.title.base, 'Stays');
  });

  testWidgets('adding a section under a facility type', (tester) async {
    final repo = FakeFlagRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Expand the first facility type
    final firstType = CatalogContent.defaults.facilityTypes.first.title.base;
    await tester.tap(find.text(firstType).first);
    await tester.pumpAndSettle();

    // Tap "Add section"
    await tester.tap(find.text('Add section'));
    await tester.pumpAndSettle();

    expect(find.text('New section'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Rooftop Venues',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Id'),
      'rooftop_venues',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Rooftop Venues').first, findsOneWidget);
    expect(_publishEnabled(tester), isTrue);

    await tester.tap(_publishButton());
    await tester.pumpAndSettle();

    final published = CatalogContent.fromJson(repo.saved.single);
    expect(published.sectionFor('rooftop_venues'), isNotNull);
  });

  testWidgets('discarding changes reverts to the published state',
      (tester) async {
    final repo = FakeFlagRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Make an edit
    await _editFirstFacilityType(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Modified');
    await tester.pumpAndSettle();
    expect(_publishEnabled(tester), isTrue);

    // Open the menu and tap Discard
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();

    // Confirm discard
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    // Publish should be disabled again (no unsaved changes)
    expect(_publishEnabled(tester), isFalse);
    expect(repo.saved, isEmpty);
  });

  testWidgets('switching language shows translation fields', (tester) async {
    await tester.pumpWidget(_app(FakeFlagRepository()));
    await tester.pumpAndSettle();

    await _editFirstFacilityType(tester);

    // Default language is shown
    expect(find.text('Title'), findsOneWidget);

    // Switch to Telugu
    await tester.tap(find.text('Telugu'));
    await tester.pumpAndSettle();

    // Translation fields should appear
    expect(find.text('Title translation'), findsOneWidget);
    expect(find.textContaining('Default:'), findsOneWidget);
  });

  testWidgets('entering a duplicate key is rejected by the dialog',
      (tester) async {
    await tester.pumpWidget(_app(FakeFlagRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add facility type'));
    await tester.pumpAndSettle();

    // Try to use an existing key
    final existingKey = CatalogContent.defaults.facilityTypes.first.key;
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Id'),
      existingKey,
    );
    await tester.pumpAndSettle();

    // The Add button should still be there (validation happens on tap)
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // Dialog should still be open (validation error shown)
    expect(find.text('New facility type'), findsOneWidget);
  });

  testWidgets('the preview shows only enabled entries', (tester) async {
    final repo = FakeFlagRepository();
    await tester.pumpWidget(_app(repo));
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();

    // All defaults should appear in preview
    for (final type in CatalogContent.defaults.visible) {
      expect(
        find.text(type.titleFor('en', fallback: type.key)).first,
        findsOneWidget,
        reason: 'missing preview for ${type.key}',
      );
    }
  });

  testWidgets('the back button on mobile returns to the tree', (tester) async {
    await tester.pumpWidget(_app(FakeFlagRepository()));
    await tester.pumpAndSettle();

    // Select a node to show the editor on mobile
    await _editFirstFacilityType(tester);

    // The "Back to catalogue" bar should be visible on mobile
    expect(find.text('Back to catalogue'), findsOneWidget);

    await tester.tap(find.text('Back to catalogue'));
    await tester.pumpAndSettle();

    // Should be back to the tree view
    expect(find.text('Add facility type'), findsOneWidget);
  });
}
