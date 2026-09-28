import 'package:bookmyspace/core/config/settings_controller.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/widgets/language_picker_sheet.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';

void main() {
  group('filterLanguages', () {
    test('empty query returns every supported locale', () {
      expect(filterLanguages(''), AppLocalizations.supportedLocales);
    });

    test('matches English names case-insensitively', () {
      expect(filterLanguages('tel').map((l) => l.languageCode), ['te']);
      expect(filterLanguages('HINDI').single.languageCode, 'hi');
    });

    test('matches native-script names and codes', () {
      expect(filterLanguages('తెలుగు').single.languageCode, 'te');
      expect(filterLanguages('ml').single.languageCode, 'ml');
      expect(filterLanguages('Espa').single.languageCode, 'es');
    });

    test('unknown query returns nothing', () {
      expect(filterLanguages('klingon'), isEmpty);
    });

    test('every supported locale has an English name', () {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(kLanguageEnglishNames[locale.languageCode], isNotNull);
      }
    });
  });

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
  }

  testWidgets('settings language picker filters and switches locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await pumpSettings(tester);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('language-search')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('language-search')), 'tam');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-language-ta')), findsOneWidget);
    expect(find.byKey(const Key('settings-language-hi')), findsNothing);

    await tester.enterText(find.byKey(const Key('language-search')), 'xyz');
    await tester.pumpAndSettle();
    expect(find.textContaining('No languages match'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('language-search')), 'हिन्दी');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-language-hi')));
    await tester.pumpAndSettle();
    expect(container.read(localeProvider).languageCode, 'hi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('simple mode and quick-book toggles update providers', (
    tester,
  ) async {
    final container = await pumpSettings(tester);
    expect(container.read(simpleModeProvider), isFalse);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-simple-mode')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pump();
    expect(container.read(simpleModeProvider), isTrue);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-quick-book')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pump();
    expect(container.read(bookingModeProvider), BookingMode.quick);
  });
}
