import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/admin/domain/admin_directory.dart';
import 'package:bookmyspace/features/admin/presentation/admin_providers.dart';
import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../booking/mock_booking_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../offers/mock_coupon_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'mock_admin_directory_repository.dart';

Widget _app({
  required Set<AppRole> roles,
  required String location,
}) {
  const user = AuthUser(id: 'u1', email: 'a@b.com');
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: user),
      ),
      currentUserRolesProvider.overrideWith((ref) async => roles),
      venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
      eventRepositoryProvider.overrideWithValue(MockEventRepository()),
      courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
      couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
      bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
      adminDirectoryRepositoryProvider.overrideWithValue(
        MockAdminDirectoryRepository(
          users: const [
            AdminUserRecord(
              id: 'u1',
              fullName: 'Ada Admin',
              email: 'ada@test.com',
              roles: ['administrator'],
            ),
          ],
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: location,
        currentUser: user,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('customer is denied Admin console', (tester) async {
    await tester.pumpWidget(
      _app(roles: {AppRole.customer}, location: AppRoutes.adminDashboard),
    );
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('Admin console'), findsNothing);
  });

  testWidgets('owner is denied Admin console', (tester) async {
    await tester.pumpWidget(
      _app(roles: {AppRole.venueOwner}, location: AppRoutes.adminDashboard),
    );
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('administrator can open Admin console and users', (tester) async {
    await tester.pumpWidget(
      _app(
        roles: {AppRole.administrator},
        location: AppRoutes.adminDashboard,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Admin console'), findsOneWidget);
    expect(find.text('Users'), findsWidgets);
  });

  testWidgets('customer is denied Owner dashboard', (tester) async {
    await tester.pumpWidget(
      _app(roles: {AppRole.customer}, location: AppRoutes.ownerDashboard),
    );
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
  });
}
