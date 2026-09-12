import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:bookmyspace/features/venues/presentation/screens/venue_details_screen.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../booking/mock_booking_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../offers/mock_coupon_repository.dart';
import '../reviews/mock_review_repository.dart';
import 'mock_venue_repository.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';

Widget _app(
  MockVenueRepository venueRepo, {
  MockAuthRepository? authRepo,
  String initialLocation = AppRoutes.home,
}) {
  final auth = authRepo ??
      MockAuthRepository(
        initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      );
  return ProviderScope(
    overrides: [
      venueRepositoryProvider.overrideWithValue(venueRepo),
      authRepositoryProvider.overrideWithValue(auth),
      eventRepositoryProvider.overrideWithValue(MockEventRepository()),
      courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
      reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
      couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
      bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: initialLocation,
        currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
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

Widget _searchApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: const SearchScreen(initialCategory: 'meeting_room'),
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
  testWidgets('venue details shows name, location and booking CTA',
      (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo, initialLocation: '/venues/v1'));
    await tester.pumpAndSettle();

    expect(find.byType(VenueDetailsScreen), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.textContaining('Book Now'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
  });

  testWidgets('venue details error recovers on retry', (tester) async {
    final repo = MockVenueRepository()..failRequests = true;
    await tester.pumpWidget(_app(repo, initialLocation: '/venues/v1'));
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsWidgets);

    repo.failRequests = false;
    await tester.tap(find.text('Try Again').first);
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
  });

  testWidgets('initial search category filters results without provider writes',
      (tester) async {
    final repo = MockVenueRepository();
    final container = ProviderContainer(
      overrides: [
        venueRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(
            initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
        ),
        couponRepositoryProvider.overrideWithValue(MockCouponRepository()),
        bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_searchApp(container));
    await tester.pumpAndSettle();

    expect(find.text('The Work Nest'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsNothing);
  });

  testWidgets('search route query parameter selects the category',
      (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(
      _app(repo, initialLocation: '/search?category=meeting_room'),
    );
    await tester.pumpAndSettle();

    expect(find.text('The Work Nest'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsNothing);
  });

  testWidgets('filters sheet has a back button and does not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(MockVenueRepository(), initialLocation: AppRoutes.search),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('filters_back')), findsOneWidget);
    expect(find.text('Clear Filters'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('filters_min_price')), '1000');
    await tester.enterText(find.byKey(const Key('filters_max_price')), '90000');
    await tester.tap(find.byKey(const Key('filters_apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filters_back')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
