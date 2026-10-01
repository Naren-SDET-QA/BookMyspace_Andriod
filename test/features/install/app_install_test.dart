import 'package:bookmyspace/features/admin/domain/admin_settings.dart';
import 'package:bookmyspace/features/admin/domain/app_install_config.dart';
import 'package:bookmyspace/features/admin/presentation/admin_settings_providers.dart';
import 'package:bookmyspace/features/admin/presentation/widgets/app_install_section.dart';
import 'package:bookmyspace/features/install/presentation/app_install_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _play =
    'https://play.google.com/store/apps/details?id=com.bookmyspace.app';
const _apk = 'https://downloads.example.com/bookmyspace.apk';

void main() {
  test('install stays off until an admin turns a channel on', () {
    final config = AppInstallConfig.fromMap(const {});
    expect(config.webEnabled, isFalse);
    expect(config.hasPlayLink, isFalse);
    expect(config.hasApkLink, isFalse);
    expect(config.saveError, isNull);
    expect(config.choicesFor(AppInstallSurface.web), isEmpty);
    expect(AdminSettings.defaults.appInstall.webEnabled, isFalse);
    expect(const AdminSettings().appInstall.androidEnabled, isFalse);
  });

  test('only https Play Store and APK links can be saved', () {
    expect(isPlayStoreHttpsUrl(_play), isTrue);
    expect(
      isPlayStoreHttpsUrl('http://play.google.com/store/apps/details?id=a'),
      isFalse,
    );
    expect(
      isPlayStoreHttpsUrl('https://evil.com/store/apps/details?id=a'),
      isFalse,
    );
    expect(
      isPlayStoreHttpsUrl('https://play.google.com.evil.com/store'),
      isFalse,
    );
    expect(isPlayStoreHttpsUrl('javascript:alert(1)'), isFalse);
    expect(isHttpsUrl(_apk), isTrue);
    expect(isHttpsUrl('http://downloads.example.com/app.apk'), isFalse);
    expect(isHttpsUrl('javascript:alert(1)'), isFalse);

    const badPlay = AppInstallConfig(
      androidEnabled: true,
      playStoreUrl: 'https://example.com/app',
    );
    expect(badPlay.saveError, contains('play.google.com'));

    const badApk = AppInstallConfig(
      apkEnabled: true,
      apkUrl: 'file:///tmp/a.apk',
    );
    expect(badApk.saveError, contains('https'));

    const ready = AppInstallConfig(
      webEnabled: true,
      androidEnabled: true,
      apkEnabled: true,
      playStoreUrl: _play,
      apkUrl: _apk,
    );
    expect(ready.saveError, isNull);
    expect(ready.choicesFor(AppInstallSurface.web), [
      AppInstallChoice.web,
      AppInstallChoice.play,
      AppInstallChoice.apk,
    ]);
    expect(ready.choicesFor(AppInstallSurface.webIos), [AppInstallChoice.web]);
    expect(ready.choicesFor(AppInstallSurface.android), [
      AppInstallChoice.play,
      AppInstallChoice.apk,
    ]);
    expect(ready.choicesFor(AppInstallSurface.ios), isEmpty);
    expect(ready.choicesFor(AppInstallSurface.web, webInstalled: true), [
      AppInstallChoice.play,
      AppInstallChoice.apk,
    ]);
  });

  testWidgets('admin cannot save an enabled channel with an unsafe link', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInstallSection(
            install: AppInstallConfig.defaultMap,
            onSave: (values) async => saved = values,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('admin-install-android')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-install-save')));
    await tester.pump();
    expect(
      find.text(
        'Play Store link must be an https://play.google.com/store URL.',
      ),
      findsOneWidget,
    );
    expect(saved, isNull);
    ScaffoldMessenger.of(
      tester.element(find.byType(AppInstallSection)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('admin-install-play-url')),
      _play,
    );
    await tester.tap(find.byKey(const Key('admin-install-apk')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('admin-install-apk-url')),
      'javascript:alert(1)',
    );
    await tester.tap(find.byKey(const Key('admin-install-save')));
    await tester.pump();
    expect(
      find.textContaining('APK link must be an https URL'),
      findsOneWidget,
    );
    expect(saved, isNull);
    ScaffoldMessenger.of(
      tester.element(find.byType(AppInstallSection)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('admin-install-apk-url')),
      _apk,
    );
    await tester.tap(find.byKey(const Key('admin-install-web')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-install-save')));
    await tester.pump();

    expect(saved?['web_enabled'], isTrue);
    expect(saved?['android_enabled'], isTrue);
    expect(saved?['apk_enabled'], isTrue);
    expect(saved?['play_store_url'], _play);
    expect(saved?['apk_url'], _apk);
  });

  testWidgets('customers see the install actions for their device', (
    tester,
  ) async {
    Future<void> pump(AppInstallSurface surface) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminSettingsProvider.overrideWith(
              (ref) async => const AdminSettings(
                install: {
                  'web_enabled': true,
                  'android_enabled': true,
                  'apk_enabled': true,
                  'play_store_url': _play,
                  'apk_url': _apk,
                  'title': 'Get the app',
                  'message': 'Book faster on your phone.',
                },
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: AppInstallCard(surface: surface)),
          ),
        ),
      );
    }

    await pump(AppInstallSurface.web);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-install-card')), findsOneWidget);
    expect(find.text('Get the app'), findsOneWidget);
    expect(find.byKey(const Key('app-install-web')), findsOneWidget);
    expect(find.byKey(const Key('app-install-play')), findsOneWidget);
    expect(find.byKey(const Key('app-install-apk')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-install-web')));
    await tester.pumpAndSettle();
    expect(find.text('Install the web app'), findsOneWidget);
    expect(find.textContaining('browser menu'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await pump(AppInstallSurface.webIos);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-install-web')), findsOneWidget);
    expect(find.byKey(const Key('app-install-play')), findsNothing);
    expect(find.byKey(const Key('app-install-apk')), findsNothing);
    await tester.tap(find.byKey(const Key('app-install-web')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Safari'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await pump(AppInstallSurface.android);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-install-web')), findsNothing);
    expect(find.byKey(const Key('app-install-play')), findsOneWidget);
    expect(find.byKey(const Key('app-install-apk')), findsOneWidget);

    await pump(AppInstallSurface.ios);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-install-card')), findsNothing);
  });

  testWidgets('a turned-off install offer is hidden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminSettingsProvider.overrideWith(
            (ref) async => AdminSettings.defaults,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AppInstallCard(surface: AppInstallSurface.web)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-install-card')), findsNothing);
  });
}
