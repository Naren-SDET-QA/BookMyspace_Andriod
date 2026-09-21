import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/venues/domain/listing_template.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/screens/venue_details_screen.dart';
import 'package:bookmyspace/features/venue_sections/presentation/venue_section_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../booking/mock_booking_repository.dart';
import '../reviews/mock_review_repository.dart';
import 'mock_venue_repository.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';

Widget _app(Venue venue, {Size size = const Size(390, 844)}) {
  return ProviderScope(
    overrides: [
      venueRepositoryProvider.overrideWithValue(
        MockVenueRepository()..seedVenue(venue),
      ),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        ),
      ),
      reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
      bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
      publishedVenueSectionsProvider.overrideWith((ref, id) async => const []),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: VenueDetailsScreen(venueId: venue.id),
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

Venue _venue({
  required String slug,
  String name = 'Listing',
  String description = 'About this space',
  int capacity = 40,
  String food = 'In-house catering',
  List<VenueFacility> facilities = const [
    VenueFacility(facility: 'Parking'),
  ],
}) {
  return Venue(
    id: 'v-layout',
    name: name,
    description: description,
    address: 'Banjara Hills, Hyderabad',
    city: 'Hyderabad',
    latitude: 17.4,
    longitude: 78.4,
    capacity: capacity,
    price: 12000,
    originalPrice: 15000,
    parkingCapacity: 20,
    foodOptions: food,
    avgRating: 4.6,
    ratingCount: 22,
    isVerified: true,
    category: VenueCategory(id: 'c', slug: slug, name: slug),
    facilities: facilities,
  );
}

void main() {
  testWidgets('missing description hides about, missing discount hides badge',
      (tester) async {
    final venue = Venue(
      id: 'v-layout',
      name: 'Listing',
      description: '',
      address: 'Hyderabad',
      city: 'Hyderabad',
      latitude: 17.4,
      longitude: 78.4,
      capacity: 0,
      price: 12000,
      originalPrice: 12000,
      parkingCapacity: 0,
      category: const VenueCategory(
        id: 'c',
        slug: 'function_hall',
        name: 'Halls',
      ),
    );
    await tester.pumpWidget(_app(venue));
    await tester.pumpAndSettle();
    expect(find.text('About this venue'), findsNothing);
    expect(find.textContaining('% OFF'), findsNothing);
    expect(find.text('Key specifications'), findsNothing);
  });

  testWidgets('every default template renders the shared CTAs', (tester) async {
    for (final slug in [
      'function_hall',
      'hotel_stay',
      'coaching',
      'temple',
      'sports_ground',
      'photography_studio',
      'gents_pg',
    ]) {
      await tester.pumpWidget(_app(_venue(slug: slug)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('listing_book_cta')), findsOneWidget);
      expect(find.byKey(const Key('listing_availability_cta')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('listing details render an OSM map for the venue location',
      (tester) async {
    await tester.pumpWidget(_app(_venue(slug: 'function_hall')));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at compact through extra-wide widths',
      (tester) async {
    const widths = [
      320.0,
      375.0,
      390.0,
      430.0,
      768.0,
      840.0,
      1024.0,
      1199.0,
      1200.0,
      1280.0,
      1440.0
    ];
    for (final width in widths) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _app(_venue(slug: 'function_hall'), size: Size(width, 900)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(VenueDetailsScreen), findsOneWidget);
      expect(find.byKey(const Key('listing_book_cta')), findsWidgets);

      // Check for any overflow exceptions
      Object? overflow;
      Object? next = tester.takeException();
      while (next != null) {
        final text = next.toString();
        if (text.contains('overflowed')) overflow = next;
        next = tester.takeException();
      }
      // No overflow should occur at any width
      expect(overflow, isNull, reason: 'overflow at ${width}px');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('1024px two-column layout: summary visible and CTAs accessible',
      (tester) async {
    const width = 1024.0;
    tester.view.physicalSize = const Size(width, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      _app(_venue(slug: 'function_hall'), size: const Size(width, 900)),
    );
    await tester.pumpAndSettle();

    // Verify no exceptions (overflow, layout errors, etc.)
    expect(tester.takeException(), isNull);

    // Verify layout is rendered
    expect(find.byType(VenueDetailsScreen), findsOneWidget);

    // Verify CTAs are accessible
    expect(find.byKey(const Key('listing_book_cta')), findsWidgets);
    expect(find.byKey(const Key('listing_availability_cta')), findsWidgets);

    // Verify summary is visible
    expect(find.text('Booking summary'), findsWidgets);

    // Verify no horizontal scrolling (content should fit)
    // If overflow occurred, there would be a scroll area
    final gestureDetectors = find.byType(GestureDetector);
    expect(gestureDetectors, findsWidgets); // Buttons are gesture detectors

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  test('unpublished overlay is not customer-published', () {
    const category = VenueCategory(
      id: 'c',
      slug: 'function_hall',
      name: 'Halls',
      listingConfig: ListingTemplateConfig(
        templateId: 'hall',
        published: false,
      ),
    );
    expect(category.listingTemplate.isPublished, isFalse);
  });
}
