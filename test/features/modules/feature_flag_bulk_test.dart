import 'dart:convert';

import 'package:bookmyspace/features/modules/domain/feature_flag.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag_bulk.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag_repository.dart';
import 'package:bookmyspace/features/modules/presentation/module_manifests.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:bookmyspace/features/modules/presentation/screens/admin_modules_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FeatureFlag _flag(String key, bool enabled, {Map<String, dynamic>? config}) =>
    FeatureFlag(
      key: key,
      enabled: enabled,
      platforms: const ['ios', 'android', 'web'],
      config: config ?? const {},
    );

Map<String, FeatureFlag> _defaults() => {
  for (final m in optionalModuleManifests) m.id: m.fallback(),
};

class _FakeFlagRepository implements FeatureFlagRepository {
  _FakeFlagRepository(this.rows);

  final List<FeatureFlag> rows;
  final saved = <String, bool>{};
  Set<String> failKeys = {};

  @override
  Future<List<FeatureFlag>> listFlags() async => List.of(rows);

  @override
  Future<FeatureFlag> saveFlag({
    required String key,
    required bool enabled,
    required List<String> platforms,
    required Map<String, dynamic> config,
  }) async {
    if (failKeys.contains(key)) throw Exception('unsupported_module');
    saved[key] = enabled;
    final row = FeatureFlag(
      key: key,
      enabled: enabled,
      platforms: platforms,
      config: config,
    );
    rows
      ..removeWhere((r) => r.key == key)
      ..add(row);
    return row;
  }
}

void main() {
  group('bulk planning', () {
    test('enable all skips already-on and layout documents', () {
      final current = _defaults()
        ..['referrals'] = _flag('referrals', false)
        ..['category_catalog'] = _flag('category_catalog', false);
      final changes = planEnableAll(current);
      expect(changes.map((c) => c.key), ['referrals']);
      expect(changes.single.summary, 'off → on');
    });

    test('disable non-core keeps server-locked modules and documents', () {
      final changes = planDisableNonCore(_defaults());
      final keys = changes.map((c) => c.key).toSet();
      expect(keys, isNot(contains('courses')));
      expect(keys, isNot(contains('home_appearance')));
      expect(keys, isNot(contains('nav_tabs')));
      expect(keys, isNot(contains('category_catalog')));
      expect(keys, isNot(contains('referrals'))); // already off
      expect(keys, containsAll(['offers', 'events', 'reviews']));
      expect(changes.every((c) => !c.after.enabled), isTrue);
    });

    test('presets map to real module keys', () {
      final hospitality = planPreset(
        _defaults(),
        FeaturePreset.hospitalityAndPg,
      );
      expect(hospitality.map((c) => c.key).toSet(), {
        'events',
        'demo_registration',
        'course_feedback',
      });
      final events = planPreset(_defaults(), FeaturePreset.eventsAndBanquets);
      expect(events.map((c) => c.key).toSet(), {
        'demo_registration',
        'course_feedback',
      });
      for (final preset in FeaturePreset.values) {
        for (final key in preset.targets.keys) {
          expect(moduleManifestFor(key), isNotNull, reason: key);
        }
      }
    });

    test('reset to defaults restores enabled and config', () {
      final current = _defaults()
        ..['analytics'] = _flag('analytics', false, config: {'max_items': 5});
      final changes = planResetToDefaults(current, _defaults());
      expect(changes.single.key, 'analytics');
      expect(changes.single.after.enabled, isTrue);
      expect(changes.single.after.config, {'max_items': 100});
      expect(changes.single.summary, 'off → on · config updated');
    });
  });

  group('json export/import', () {
    test('export round-trips as a no-op import', () {
      final current = _defaults();
      final json = exportFlagsJson(current);
      final decoded = jsonDecode(json) as Map;
      expect((decoded['flags'] as List).length, current.length);
      final result = parseFlagsImport(json, current);
      expect(result.isValid, isTrue);
      expect(result.changes, isEmpty);
    });

    test('import diff detects enabled and config changes', () {
      final current = _defaults();
      final result = parseFlagsImport(
        jsonEncode({
          'flags': [
            {'key': 'events', 'enabled': false},
            {
              'key': 'analytics',
              'config': {'max_items': 10},
            },
          ],
        }),
        current,
      );
      expect(result.isValid, isTrue);
      expect(result.changes.map((c) => c.key), ['events', 'analytics']);
      expect(result.changes.last.after.enabled, isTrue);
    });

    test('import accepts a {key: bool} map', () {
      final result = parseFlagsImport('{"referrals": true}', _defaults());
      expect(result.changes.single.key, 'referrals');
    });

    test('import rejects invalid input', () {
      final current = _defaults();
      expect(parseFlagsImport('not json', current).isValid, isFalse);
      expect(parseFlagsImport('42', current).isValid, isFalse);
      final bad = parseFlagsImport(
        jsonEncode([
          {'key': 'mystery', 'enabled': true},
          {'key': 'events', 'enabled': 'yes'},
          {
            'key': 'offers',
            'platforms': ['desktop'],
          },
          {'key': 'reviews', 'config': 'x'},
          {'key': 'courses', 'enabled': false},
        ]),
        current,
      );
      expect(bad.isValid, isFalse);
      expect(bad.errors, hasLength(5));
      expect(bad.changes, isEmpty);
    });
  });

  group('AdminModulesScreen bulk actions', () {
    Widget app(_FakeFlagRepository repo) => ProviderScope(
      overrides: [featureFlagRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: AdminModulesScreen()),
    );

    testWidgets('enable all previews then writes each flag', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeFlagRepository([
        _flag('events', false),
        _flag('reviews', false),
      ]);
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AdminModulesScreen.enableAllKey));
      await tester.pumpAndSettle();
      expect(
        find.text('Apply 3'),
        findsOneWidget,
      ); // events, reviews, referrals
      await tester.tap(find.byKey(AdminModulesScreen.applyChangesKey));
      await tester.pumpAndSettle();

      expect(repo.saved, {'events': true, 'reviews': true, 'referrals': true});
      expect(find.textContaining('3 modules updated'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelling the preview writes nothing', (tester) async {
      final repo = _FakeFlagRepository([]);
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AdminModulesScreen.disableNonCoreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
    });

    testWidgets('reports modules the backend rejected', (tester) async {
      final repo = _FakeFlagRepository([_flag('events', true)])
        ..failKeys = {'demo_registration'};
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          AdminModulesScreen.presetKey(FeaturePreset.hospitalityAndPg),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AdminModulesScreen.applyChangesKey));
      await tester.pumpAndSettle();

      expect(repo.saved['events'], isFalse);
      expect(
        find.textContaining('not saved: demo_registration'),
        findsOneWidget,
      );
    });

    testWidgets('export copies JSON and import validates, previews, applies', (
      tester,
    ) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final repo = _FakeFlagRepository([]);
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AdminModulesScreen.exportKey));
      await tester.pumpAndSettle();
      expect(clipboard, contains('"key": "events"'));

      await tester.tap(find.byKey(AdminModulesScreen.importKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(AdminModulesScreen.importFieldKey),
        '{"bogus": true}',
      );
      await tester.tap(find.byKey(AdminModulesScreen.importValidateKey));
      await tester.pumpAndSettle();
      expect(find.text('Unknown module "bogus".'), findsOneWidget);

      await tester.enterText(
        find.byKey(AdminModulesScreen.importFieldKey),
        '{"events": false}',
      );
      await tester.tap(find.byKey(AdminModulesScreen.importValidateKey));
      await tester.pumpAndSettle();
      expect(find.text('Review import'), findsOneWidget);
      expect(find.text('on → off'), findsOneWidget);
      await tester.tap(find.byKey(AdminModulesScreen.applyChangesKey));
      await tester.pumpAndSettle();

      expect(repo.saved, {'events': false});
    });
  });
}
