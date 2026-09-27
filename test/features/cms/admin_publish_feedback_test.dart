import 'dart:async';

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/widgets/publish_feedback.dart';
import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:bookmyspace/features/auth/presentation/widgets/role_gate.dart';
import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/presentation/screens/admin_catalog_screen.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag_repository.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flag store whose write completes only when the test says so, so the test
/// can change app state while a publish is in flight.
class _GatedRepo implements FeatureFlagRepository {
  final gate = Completer<void>();
  final saved = <Map<String, dynamic>>[];

  @override
  Future<List<FeatureFlag>> listFlags() async => const [];

  @override
  Future<FeatureFlag> saveFlag({
    required String key,
    required bool enabled,
    required List<String> platforms,
    required Map<String, dynamic> config,
  }) async {
    await gate.future;
    saved.add(config);
    return FeatureFlag(
      key: key,
      enabled: enabled,
      platforms: platforms,
      config: config,
    );
  }
}

final _rolesTick = StateProvider<int>((ref) => 0);

void main() {
  testWidgets('showSnackBarAfterFrame shows after the frame and ignores null', (
    tester,
  ) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: key,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    showSnackBarAfterFrame(null, const SnackBar(content: Text('nope')));
    showSnackBarAfterFrame(
      key.currentState,
      const SnackBar(content: Text('Published')),
    );
    expect(find.text('Published'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('nope'), findsNothing);
  });

  testWidgets(
    'a publish that succeeds while the screen is rebuilt reports success, '
    'not "Could not publish"',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _GatedRepo();
      final container = ProviderContainer(
        overrides: [
          featureFlagRepositoryProvider.overrideWithValue(repo),
          // Roles reload whenever an upstream value changes, as they do on
          // real auth updates; RoleGate rebuilds the screen underneath.
          currentUserRolesProvider.overrideWith((ref) async {
            ref.watch(_rolesTick);
            return {AppRole.administrator};
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: RoleGate(
              requiredRoles: {AppRole.administrator},
              child: AdminCatalogScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = CatalogContent.defaults.facilityTypes.first.title.base;
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Celebrations');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
      await tester.pump();

      // The app rebuilds around the screen while the write is in flight.
      container.read(_rolesTick.notifier).state++;
      await tester.pump();

      repo.gate.complete();
      await tester.pumpAndSettle();

      expect(repo.saved, hasLength(1));
      expect(find.text('Catalogue published'), findsOneWidget);
      expect(find.textContaining('Could not publish'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
