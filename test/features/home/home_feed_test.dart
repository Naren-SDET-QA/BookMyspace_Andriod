import 'dart:async';

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/home/presentation/discovery_location.dart';
import 'package:bookmyspace/features/home/presentation/screens/home_screen.dart';
import 'package:bookmyspace/features/location/domain/gps_location.dart';
import 'package:bookmyspace/features/location/presentation/gps_session.dart';
import 'package:bookmyspace/features/location/presentation/location_providers.dart';
import 'package:bookmyspace/features/offers/domain/coupon.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/mock_auth_repository.dart';
import '../booking/mock_booking_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../offers/mock_coupon_repository.dart';
import '../reviews/mock_review_repository.dart';
import '../venues/mock_venue_repository.dart';

void main() {
  testWidgets('home shows location selector, voice, spotlight and live offers',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final events = MockEventRepository()
      ..upcoming = [MockEventRepository.sampleEvent()];
    final courses = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()];
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) => Text('search:${state.uri.query}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          eventRepositoryProvider.overrideWithValue(events),
          courseRepositoryProvider.overrideWithValue(courses),
          publishedCoursesProvider.overrideWith(
            (ref) async => courses.courses,
          ),
          reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
          couponRepositoryProvider.overrideWithValue(
            MockCouponRepository(
              coupons: const [
                Coupon(
                  id: 'c1',
                  code: 'HALL10',
                  discountType: 'percentage',
                  discountValue: 10,
                  description: 'Hall weekday offer',
                ),
              ],
            ),
          ),
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
    await tester.pumpAndSettle();

    expect(find.text('Select location'), findsWidgets);
    expect(find.text('Say a city, category, or budget...'), findsOneWidget);
    expect(
      find.text('Voice search uses the same live filters as typed search.'),
      findsOneWidget,
    );
    expect(find.text('Book More, Save More!'), findsOneWidget);
    expect(find.text('Use code HALL10'), findsOneWidget);
    expect(find.text('Top-rated spaces'), findsOneWidget);
    expect(find.text('HALL10'), findsWidgets);
    expect(find.text('Upcoming events'), findsOneWidget);
    expect(find.text('Hyderabad Music Night'), findsOneWidget);
    expect(find.text('Hyderabad (Madhapur)'), findsNothing);
    expect(find.text('Explore Verified Spaces'), findsOneWidget);
  });

  testWidgets('location sheet shows GPS and PIN without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.search,
          builder: (context, state) => Text('search:${state.uri.query}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          eventRepositoryProvider.overrideWithValue(MockEventRepository()),
          courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
          reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
          couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
          bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select location').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.text('Find by Indian PIN code'), findsOneWidget);
    expect(find.text('Lookup'), findsOneWidget);
  });

  testWidgets('GPS timeout leaves the sheet and never keeps a spinner',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final hanging = _HangingGpsService();
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          eventRepositoryProvider.overrideWithValue(MockEventRepository()),
          courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
          reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
          couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
          bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
          gpsLocationServiceProvider.overrideWithValue(hanging),
          gpsSessionProvider.overrideWith(
            (ref) => GpsSessionNotifier(
              ref.watch(gpsLocationServiceProvider),
              overallTimeout: const Duration(milliseconds: 50),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select location').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my current location'));
    await tester.pump();
    expect(find.text('Getting your location…'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Location request timed out'), findsOneWidget);
    expect(find.text('Getting your location…'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(hanging.requestCount, 1);
  });

  testWidgets('successful GPS applies the live city and exits loading',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          eventRepositoryProvider.overrideWithValue(MockEventRepository()),
          courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
          reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
          couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
          bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
          gpsLocationServiceProvider.overrideWithValue(
            _ImmediateGpsService(
              const GpsResult(
                status: GpsRequestStatus.success,
                fix: GpsFix(
                  latitude: 15.8497,
                  longitude: 74.4977,
                  city: 'Belagavi',
                  label: 'Belagavi',
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select location').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    expect(find.text('Getting your location…'), findsNothing);
    expect(find.text('Belagavi'), findsWidgets);
    await tester.tap(find.text('Apply this location').first);
    await tester.pumpAndSettle();
    expect(find.text('Near you'), findsOneWidget);
  });

  test('discovery location is only updated by user actions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(discoveryLocationProvider).hasCity, isFalse);
    container.read(discoveryLocationProvider.notifier).setCity('Bengaluru');
    expect(container.read(discoveryLocationProvider).city, 'Bengaluru');
    container.read(discoveryLocationProvider.notifier).setRadiusKm(5);
    expect(container.read(discoveryLocationProvider).radiusKm, 5);
  });
}

class _HangingGpsService implements GpsLocationService {
  int requestCount = 0;
  final Completer<GpsResult> _completer = Completer<GpsResult>();

  @override
  Future<GpsPermissionState> checkPermission() async =>
      GpsPermissionState.notRequested;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<GpsResult> requestCurrentLocation({
    GpsPhaseCallback? onPhase,
    Duration locationTimeout = const Duration(seconds: 10),
    Duration geocodeTimeout = const Duration(seconds: 10),
  }) {
    requestCount++;
    onPhase?.call(GpsPhase.loadingLocation);
    return _completer.future;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class _ImmediateGpsService implements GpsLocationService {
  _ImmediateGpsService(this.result);

  final GpsResult result;

  @override
  Future<GpsPermissionState> checkPermission() async =>
      GpsPermissionState.granted;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<GpsResult> requestCurrentLocation({
    GpsPhaseCallback? onPhase,
    Duration locationTimeout = const Duration(seconds: 10),
    Duration geocodeTimeout = const Duration(seconds: 10),
  }) async {
    onPhase?.call(GpsPhase.success);
    return result;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
