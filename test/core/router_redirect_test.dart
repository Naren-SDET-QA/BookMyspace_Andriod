import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/mock_auth_repository.dart';
import '../features/booking/mock_booking_repository.dart';
import '../features/courses/mock_course_repository.dart';
import '../features/events/mock_event_repository.dart';
import '../features/offers/mock_coupon_repository.dart';
import '../features/venues/mock_venue_repository.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';

Future<String> _redirectTo(
  WidgetTester tester, {
  required String initialLocation,
  required AuthUser? currentUser,
  required bool authReady,
}) async {
  final router = createAppRouter(
    initialLocation: initialLocation,
    currentUser: currentUser,
    authReady: authReady,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(initialUser: currentUser),
        ),
        venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
        eventRepositoryProvider.overrideWithValue(MockEventRepository()),
        courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
        couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
        bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
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
  await tester.pump();
  final uri = router.routeInformationProvider.value.uri.path;
  await tester.pumpWidget(const SizedBox.shrink());
  router.dispose();
  return uri;
}

void main() {
  testWidgets('unauth user on shell is redirected to login', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.shell,
      currentUser: null,
      authReady: true,
    );
    expect(uri, AppRoutes.login);
  });

  testWidgets('unauth user can stay on public login route', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.login,
      currentUser: null,
      authReady: true,
    );
    expect(uri, AppRoutes.login);
  });

  testWidgets('authenticated user on login is redirected to shell', (
    tester,
  ) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.login,
      currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      authReady: true,
    );
    expect(uri, AppRoutes.shell);
  });

  testWidgets('root path / redirects unauthenticated users to login',
      (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.root,
      currentUser: null,
      authReady: true,
    );
    expect(uri, AppRoutes.login);
  });

  testWidgets('root path / redirects authenticated users to home',
      (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.root,
      currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      authReady: true,
    );
    expect(uri, AppRoutes.shell);
  });

  testWidgets('root path / does not show page-not-found while auth loads',
      (tester) async {
    final router = createAppRouter(
      initialLocation: AppRoutes.root,
      currentUser: null,
      authReady: false,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(),
          ),
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          eventRepositoryProvider.overrideWithValue(MockEventRepository()),
          courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
          couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
          bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
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
    await tester.pump();
    expect(find.text('This page is not available.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer tab aliases resolve without unknown-route screen',
      (tester) async {
    const user = AuthUser(id: 'u1', email: 'a@b.com');
    for (final location in [
      AppRoutes.root,
      AppRoutes.home,
      AppRoutes.search,
      AppRoutes.bookings,
      AppRoutes.coursesList,
      AppRoutes.profile,
      '/alerts',
      AppRoutes.settings,
      AppRoutes.login,
    ]) {
      final uri = await _redirectTo(
        tester,
        initialLocation: location,
        currentUser: user,
        authReady: true,
      );
      expect(uri, isNot('/'), reason: location);
      expect(uri.contains('not available'), isFalse);
    }
  });

  testWidgets('root path / in preview mode goes to home', (tester) async {
    final router = createAppRouter(
      initialLocation: AppRoutes.root,
      currentUser: null,
      authReady: true,
      allowUnauthenticatedPreview: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(initialUser: null),
          ),
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          eventRepositoryProvider.overrideWithValue(MockEventRepository()),
          courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
          couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
          bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
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
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.shell);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });

  testWidgets('authenticated user can open search', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.search,
      currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      authReady: true,
    );
    expect(uri, AppRoutes.search);
  });

  testWidgets('auth not ready skips gating', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.login,
      currentUser: null,
      authReady: false,
    );
    expect(uri, AppRoutes.login);
  });
}
