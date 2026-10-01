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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'mock_auth_repository.dart';

void main() {
  group('Cross-Device Profile & Dev Role Switcher Tests', () {
    Widget createTestApp({
      required ProviderContainer container,
      Size size = const Size(800, 1200),
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const Scaffold(body: ProfileScreen()),
              ),
            ],
          ),
        ),
      );
    }

    ProviderContainer createContainer({DevRole? initialRole}) {
      return ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'test@bms.com'),
            ),
          ),
          activeDevRoleProvider.overrideWith((ref) => initialRole),
          myBookingsProvider.overrideWith((ref) async => const <Booking>[]),
          savedVenuesProvider.overrideWith((ref) async => const <Venue>[]),
          moduleEnabledProvider.overrideWith((ref, id) => true),
          walletEntriesProvider.overrideWith((ref) async => const <WalletEntry>[]),
          referralSummaryProvider.overrideWith(
            (ref) async => const ReferralSummary(code: 'TESTCODE', items: []),
          ),
        ],
      );
    }

    testWidgets('renders Role Switcher on profile and allows toggling roles', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = createContainer(initialRole: DevRole.customer);
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container: container));
      await tester.pumpAndSettle();

      // Verify the Role Switcher is visible
      expect(find.text('Switch Role (DEV Testing Mode)'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Venue Owner'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);

      // Tap Venue Owner
      await tester.tap(find.byKey(const Key('role_switch_owner')));
      await tester.pumpAndSettle();
      expect(container.read(activeDevRoleProvider), DevRole.venueOwner);

      // Tap Admin
      await tester.tap(find.byKey(const Key('role_switch_admin')));
      await tester.pumpAndSettle();
      expect(container.read(activeDevRoleProvider), DevRole.admin);

      // Tap Customer
      await tester.tap(find.byKey(const Key('role_switch_customer')));
      await tester.pumpAndSettle();
      expect(container.read(activeDevRoleProvider), DevRole.customer);
    });

    testWidgets('Responsive testing on compact phone width (360x780)', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Switch Role (DEV Testing Mode)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive testing on desktop width (1280x900)', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Switch Role (DEV Testing Mode)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
