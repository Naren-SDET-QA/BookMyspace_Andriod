import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/profile_screen.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:bookmyspace/features/rewards/domain/rewards.dart';
import 'package:bookmyspace/features/rewards/presentation/rewards_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'mock_auth_repository.dart';

const _keys = [
  'profile-payment-history',
  'profile-refer-earn',
  'profile-kyc-registration',
  'profile-institute-portal',
  'profile-owner-analytics',
];

Future<void> _pump(
  WidgetTester tester, {
  required Set<AppRole> roles,
  AuthUser? user = const AuthUser(id: 'u1', email: 'a@b.com'),
  bool modulesEnabled = true,
}) async {
  tester.view.physicalSize = const Size(320, 6400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: user),
        ),
        currentUserRolesProvider.overrideWith((ref) async => roles),
        myBookingsProvider.overrideWith((ref) async => const <Booking>[]),
        savedVenuesProvider.overrideWith((ref) async => const <Venue>[]),
        moduleEnabledProvider.overrideWith((ref, id) => modulesEnabled),
        walletEntriesProvider.overrideWith((ref) async => const <WalletEntry>[]),
        referralSummaryProvider.overrideWith(
          (ref) async => const ReferralSummary(code: 'TESTCODE', items: []),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: AppRoutes.referrals,
              builder: (context, state) =>
                  const Scaffold(body: Text('referrals-page')),
            ),
          ],
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
  });

  testWidgets('customer sees payment, referral and KYC tiles only', (
    tester,
  ) async {
    await _pump(tester, roles: {AppRole.customer});
    expect(find.byKey(const Key('profile-payment-history')), findsOneWidget);
    expect(find.byKey(const Key('profile-refer-earn')), findsOneWidget);
    expect(find.byKey(const Key('profile-kyc-registration')), findsOneWidget);
    expect(find.byKey(const Key('profile-institute-portal')), findsNothing);
    expect(find.byKey(const Key('profile-owner-analytics')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('profile-refer-earn')));
    await tester.pumpAndSettle();
    expect(find.text('referrals-page'), findsOneWidget);
  });

  testWidgets('institute and venue owners get portal and analytics', (
    tester,
  ) async {
    await _pump(tester, roles: {AppRole.instituteOwner, AppRole.venueOwner});
    for (final key in _keys) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('disabled modules hide gated tiles', (tester) async {
    await _pump(
      tester,
      roles: {AppRole.instituteOwner, AppRole.venueOwner},
      modulesEnabled: false,
    );
    expect(find.byKey(const Key('profile-refer-earn')), findsNothing);
    expect(find.byKey(const Key('profile-institute-portal')), findsNothing);
    expect(find.byKey(const Key('profile-owner-analytics')), findsNothing);
    expect(find.byKey(const Key('profile-payment-history')), findsOneWidget);
  });

  testWidgets('guests see none of the account entry points', (tester) async {
    await _pump(tester, roles: const {}, user: null);
    for (final key in _keys.take(3)) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
  });
}
