import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_state.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';

void main() {
  const user = AuthUser(id: 'u1', email: 'a@b.com');

  test('deleteAccount updates auth state on success', () async {
    final auth = MockAuthRepository(initialUser: user);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    await notifier.deleteAccount();
    expect(auth.deleteAccountCount, 1);
    expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
  });

  test('deleteAccount failure keeps the session and can be retried', () async {
    final auth = MockAuthRepository(initialUser: user)..failDeleteAccount = true;
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    await expectLater(notifier.deleteAccount(), throwsA(isA<Object>()));
    expect(auth.deleteAccountCount, 1);
    expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());

    auth.failDeleteAccount = false;
    await notifier.deleteAccount();
    expect(auth.deleteAccountCount, 2);
    expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
  });

  testWidgets('delete account dialog requires typing DELETE', (tester) async {
    final auth = MockAuthRepository(initialUser: user);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
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

    await tester.tap(find.text('Delete Account'));
    await tester.pump();
    expect(find.textContaining('Type DELETE'), findsWidgets);

    final deleteButtons = find.widgetWithText(FilledButton, 'Delete');
    expect(tester.widget<FilledButton>(deleteButtons).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(tester.widget<FilledButton>(deleteButtons).onPressed, isNotNull);
    expect(auth.deleteAccountCount, 0);
  });
}
