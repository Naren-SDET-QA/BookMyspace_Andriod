import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/home/presentation/screens/home_screen.dart';
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
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';

GoRouter _discoveryRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const Text('search-page'),
      ),
    ],
  );
}

Widget _homeApp(GoRouter router) {
  return ProviderScope(
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
      routerConfig: router,
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
  testWidgets('home shows 3D glass Function Halls matrix and hero copy',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _discoveryRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_homeApp(router));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Explore Verified Spaces'), findsOneWidget);
    expect(
      find.textContaining('Five master categories'),
      findsOneWidget,
    );
    expect(find.text('Function Halls & Celebrations'), findsWidgets);
    expect(find.byKey(const Key('function-halls-matrix')), findsOneWidget);
    expect(find.text('Marriage Halls'), findsOneWidget);
    expect(find.text('Banquet Halls'), findsOneWidget);
    expect(find.text('Convention Halls'), findsOneWidget);
    expect(find.text('Party Halls & Lawns'), findsOneWidget);
    expect(find.text('Engagement Halls'), findsOneWidget);
    expect(find.text('Reception Halls'), findsOneWidget);
    expect(find.text('Premium / Luxury Halls'), findsOneWidget);
    expect(find.text('Outdoor / Garden Venues'), findsOneWidget);

    expect(find.text('SUB-SECTIONS INCLUDED:'), findsNothing);
    expect(find.text('STARTS FROM'), findsNothing);
    expect(find.text('+ Sub-Section'), findsNothing);
    expect(find.text('1-CLICK FILTER'), findsNothing);
  });

  testWidgets('tapping a live sub-section navigates via search route params',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _discoveryRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_homeApp(router));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Party Halls & Lawns'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Party Halls & Lawns'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.search);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['category'],
      'party_hall',
    );
  });

  testWidgets(
      'unlisted Function Halls sub-section uses search query not a fake slug',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _discoveryRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_homeApp(router));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('sub-engagement_hall')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sub-engagement_hall')));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.search);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['category'],
      isNull,
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters['q'],
      'Engagement Halls',
    );
  });
}
