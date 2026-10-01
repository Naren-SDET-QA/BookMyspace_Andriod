import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/offers/presentation/coupon_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';
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
import '../reviews/mock_review_repository.dart';
import '../venues/mock_venue_repository.dart';

void main() {
  group('Home Screen Interactive Features & Responsiveness Tests', () {
    Widget buildTestApp({
      MockVenueRepository? venueRepo,
      MockAuthRepository? authRepo,
      String initialLocation = AppRoutes.home,
    }) {
      final auth = authRepo ??
          MockAuthRepository(
            initialUser: const AuthUser(id: 'u1', email: 'test@bms.com'),
          );
      final venues = venueRepo ?? MockVenueRepository();

      return ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(venues),
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
            currentUser: const AuthUser(id: 'u1', email: 'test@bms.com'),
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

    testWidgets('Renders Themes & 3D, Bol-ke-Book, Hot Deals, Scratch Pass, and Add Other', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Header branding and Themes & 3D pill
      expect(find.text('BookMySpace'), findsOneWidget);
      expect(find.text('Turfs • Halls • PGs • Studios'), findsOneWidget);
      expect(find.text('Themes & 3D'), findsOneWidget);

      // Explore categories / Trending + Add Other
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Trending Categories' ||
                  w.data == 'Explore categories'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('add-other-category-header-btn')), findsOneWidget);

      // Category Matrix
      final scrollableFinder = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('function-halls-matrix')),
        200,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('function-halls-matrix')), findsOneWidget);

      // Scroll to Bol-ke-Book Voice Search banner
      await tester.scrollUntilVisible(
        find.text('Bol-ke-Book (Voice Search)'),
        200,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();
      expect(find.text('Bol-ke-Book (Voice Search)'), findsOneWidget);
      expect(find.text('1-Tap Booking with Pictures & Voice'), findsOneWidget);

      // Scroll to Spotlight & Hot Deals
      await tester.scrollUntilVisible(
        find.text('Spotlight & Hot Deals'),
        200,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();
      expect(find.text('Spotlight & Hot Deals'), findsOneWidget);
      expect(find.text('Grand Marriage & Banquet Halls'), findsOneWidget);
      expect(find.byKey(const Key('claim-flash-deal-btn')), findsOneWidget);

      // Scroll to Daily Lucky Booking Pass
      await tester.scrollUntilVisible(
        find.text('Daily Lucky Booking Pass'),
        200,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();
      expect(find.text('Daily Lucky Booking Pass'), findsOneWidget);
      expect(find.text('FREE PASS'), findsOneWidget);
      expect(find.byKey(const Key('scratch-pass-btn')), findsOneWidget);

      // Tap to scratch
      await tester.tap(find.byKey(const Key('scratch-pass-btn')));
      await tester.pumpAndSettle();

      // Code unlocked
      expect(find.text('CODE: ROYALWED35'), findsOneWidget);
      expect(find.text('Tap to Copy'), findsOneWidget);
    });

    testWidgets('Tap + Add Other opens the Add New Category modal', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final addOtherBtn = find.byKey(const Key('add-other-category-header-btn'));
      await tester.tap(addOtherBtn);
      await tester.pumpAndSettle();

      // Check modal content
      expect(find.text('Add New Category'), findsOneWidget);
      expect(find.text('Create a custom category for any space'), findsOneWidget);
      expect(find.text('Belongs to Section *'), findsOneWidget);
      expect(find.text('Category Name *'), findsOneWidget);
      expect(find.text('Category Icon / Emoji'), findsOneWidget);
      expect(find.text('Popular Suggestions (Tap to fill)'), findsOneWidget);
      expect(find.byKey(const Key('submit-new-category-btn')), findsOneWidget);
    });

    testWidgets('Responsive phone rendering check (380x800)', (tester) async {
      tester.view.physicalSize = const Size(380, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive desktop rendering check (1440x900)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
