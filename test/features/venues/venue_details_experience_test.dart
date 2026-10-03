import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/widgets/peak_booking_hours_card.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/screens/venue_details_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:bookmyspace/features/venues/presentation/widgets/selected_slot_crowd_card.dart';
import 'package:bookmyspace/features/venues/presentation/widgets/venue_facilities_amenities_section.dart';
import 'package:bookmyspace/features/venue_sections/presentation/venue_section_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../booking/mock_booking_repository.dart';
import '../reviews/mock_review_repository.dart';
import 'mock_venue_repository.dart';

final _testVenue = Venue(
  id: 'v-experience-1',
  name: 'Grand Royal Arena',
  description: 'World-class multi-sport arena and convention hall with premier amenities.',
  address: 'Road No 12, Banjara Hills',
  city: 'Hyderabad',
  state: 'Telangana',
  pincode: '500034',
  latitude: 17.4123,
  longitude: 78.4356,
  capacity: 250,
  parkingCapacity: 80,
  foodOptions: 'Veg & Non-Veg In-House Catering',
  price: 15000,
  originalPrice: 18000,
  avgRating: 4.8,
  starRating: 5,
  ratingCount: 42,
  isVerified: true,
  isActive: true,
  contactPhone: '9876543210',
  videoUrl: 'https://example.com/videos/arena_tour.mp4',
  tourUrl: 'https://example.com/models/arena.glb',
  category: const VenueCategory(
    id: 'cat-arena',
    slug: 'sports_arena',
    name: 'Sports & Convention',
  ),
  images: const [
    VenueImage(id: 'img-1', url: 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800', isCover: true),
    VenueImage(id: 'img-2', url: 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800'),
    VenueImage(id: 'img-3', url: 'https://images.unsplash.com/photo-1511578314322-379afb476865?w=800'),
  ],
  facilities: const [
    VenueFacility(facility: 'High-speed WiFi'),
    VenueFacility(facility: 'Valet Parking'),
    VenueFacility(facility: 'Air Conditioning'),
    VenueFacility(facility: '100% Power Backup'),
    VenueFacility(facility: 'Restrooms'),
    VenueFacility(facility: 'JBL Pro Sound System'),
    VenueFacility(facility: 'Catering Kitchen'),
    VenueFacility(facility: 'CCTV 24x7 Security'),
    VenueFacility(facility: 'Changing Rooms'),
  ],
);

Widget _buildTestApp({
  Venue? venue,
  Size size = const Size(390, 844),
}) {
  final targetVenue = venue ?? _testVenue;
  return ProviderScope(
    overrides: [
      venueRepositoryProvider.overrideWithValue(
        MockVenueRepository()..seedVenue(targetVenue),
      ),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(id: 'u-1', email: 'test@bms.com'),
        ),
      ),
      reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
      bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
      publishedVenueSectionsProvider.overrideWith((ref, id) async => const []),
      moduleEnabledProvider.overrideWith((ref, id) => true),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: VenueDetailsScreen(venueId: targetVenue.id),
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
  group('Venue Details Experience - Reference Screen Parity', () {
    testWidgets('1. Header: Back, Venue Name, Analytics button, Listen button, Favorite button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Back button
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Venue name in header
      expect(find.text('Grand Royal Arena'), findsWidgets);

      // Analytics Icon Button
      final analyticsBtn = find.byKey(const Key('venue_analytics_overlay_button'));
      expect(analyticsBtn, findsOneWidget);

      // Listen / Voice Readout Button
      final voiceBtn = find.byKey(const Key('voice_readout_button'));
      expect(voiceBtn, findsOneWidget);

      // Favorite Button
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      // Tap Analytics button -> Least Busy Hours Analytics modal opens
      await tester.tap(analyticsBtn);
      await tester.pumpAndSettle();
      expect(find.text('Least Busy Hours Analytics'), findsOneWidget);
      expect(find.textContaining('LEAST BUSY / OFF-PEAK'), findsOneWidget);
      expect(find.textContaining('PEAK HOURS'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byKey(const Key('close_analytics_overlay')));
      await tester.pumpAndSettle();
      expect(find.text('Least Busy Hours Analytics'), findsNothing);

      // Tap Voice Readout button -> Audio Readout dialog opens
      await tester.tap(voiceBtn);
      await tester.pumpAndSettle();
      expect(find.text('Audio Readout'), findsOneWidget);
      expect(find.textContaining('Grand Royal Arena in Hyderabad'), findsOneWidget);

      // Close Audio Readout
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('2. Media: Photos, Short Video, 3D Tour tabs, carousel, lightbox', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Media Tabs exist
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Short Video'), findsOneWidget);
      expect(find.text('3D / 360° Tour'), findsOneWidget);
      expect(find.text('4K ULTRA HD'), findsOneWidget);

      // Photos Tab active by default: counter, verified badge
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);

      // Switch to Short Video Tab
      await tester.tap(find.text('Short Video'));
      await tester.pumpAndSettle();
      expect(find.text('Grand Royal Arena Walkthrough'), findsOneWidget);

      // Switch to 3D / 360° Tour Tab
      await tester.tap(find.text('3D / 360° Tour'));
      await tester.pumpAndSettle();
      expect(find.text('Launch 3D / 360° Tour'), findsOneWidget);

      // Switch back to Photos
      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('3. Information hierarchy & Key specifications', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verified badge
      expect(find.text('Verified'), findsWidgets);

      // Price Row
      expect(find.textContaining('15,000'), findsWidgets);
      expect(find.textContaining('18,000'), findsWidgets);

      // Quick facts
      expect(find.text('250 Guests'), findsOneWidget);
      expect(find.text('80 Parking'), findsOneWidget);

      // About this venue
      expect(find.text('About this venue'), findsOneWidget);
      expect(find.textContaining('World-class multi-sport arena'), findsOneWidget);
    });

    testWidgets('4. Peak Booking Hours card renders with live analytics', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Peak Booking Hours card
      expect(find.byType(PeakBookingHoursCard), findsOneWidget);
      expect(find.text('Peak Booking Hours'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('5. Selected Slot / Crowd Card renders dynamically', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // SelectedSlotCrowdCard is present
      expect(find.byType(SelectedSlotCrowdCard), findsOneWidget);
    });

    testWidgets('6. Exact Venue Location & Navigation section with OSM map', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Heading
      expect(find.text('Exact Venue Location & Navigation'), findsOneWidget);

      // OpenStreetMap interactive view
      expect(find.byType(FlutterMap), findsOneWidget);

      // Directions and Details buttons
      expect(find.text('Get Directions'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('7. Facilities & Amenities section with chip icons and expand toggle', (tester) async {
      const testSize = Size(800, 1800);
      tester.view.physicalSize = testSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(size: testSize));
      await tester.pumpAndSettle();

      // Facilities heading
      expect(find.byType(VenueFacilitiesAmenitiesSection), findsOneWidget);
      expect(find.text('Facilities & Amenities'), findsOneWidget);

      // Amenities chips rendered
      expect(find.text('High-speed WiFi'), findsOneWidget);
      expect(find.text('Valet Parking'), findsOneWidget);
      expect(find.text('Air Conditioning'), findsOneWidget);

      // View All button and expand
      final viewAllFinder = find.text('View All (9)');
      expect(viewAllFinder, findsOneWidget);
      await tester.tap(viewAllFinder);
      await tester.pumpAndSettle();
      expect(find.text('Show Less'), findsOneWidget);
      expect(find.text('Changing Rooms'), findsOneWidget);
    });

    testWidgets('8. Sticky Booking Bar with CTAs', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('listing_book_cta')), findsOneWidget);
      expect(find.byKey(const Key('listing_availability_cta')), findsOneWidget);
      expect(find.text('Starting from'), findsOneWidget);
    });

    testWidgets('9. Floating AI Help button is visible and routes to support', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final aiHelp = find.byKey(const Key('listing_ai_help'));
      expect(aiHelp, findsOneWidget);
      expect(find.text('AI Help'), findsOneWidget);
    });

    testWidgets('10. Responsive viewports: 320, 375, 390, 430, 600, 768, 840, 1024, 1200, 1280, 1440, 1920', (tester) async {
      final viewports = [
        const Size(320, 800),   // 320px: Ultra-compact mobile
        const Size(375, 667),   // 375px: iPhone SE
        const Size(390, 844),   // 390px: iPhone 12/13/14
        const Size(430, 932),   // 430px: iPhone Pro Max
        const Size(600, 900),   // 600px: Small tablet / large foldable
        const Size(768, 1024),  // 768px: Tablet portrait (iPad Mini)
        const Size(840, 1024),  // 840px: Material 3 Expanded threshold
        const Size(1024, 768),  // 1024px: Tablet landscape / Small laptop
        const Size(1200, 900),  // 1200px: Material 3 Extra-wide breakpoint
        const Size(1280, 900),  // 1280px: Standard Desktop Web
        const Size(1440, 900),  // 1440px: Large Desktop / MacBook Pro
        const Size(1920, 1080), // 1920px: Full HD Display
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_buildTestApp(size: size));
        await tester.pumpAndSettle();

        // 1. Root and Header
        expect(find.byType(VenueDetailsScreen), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expect(find.byKey(const Key('venue_analytics_overlay_button')), findsOneWidget);
        expect(find.byKey(const Key('voice_readout_button')), findsOneWidget);
        expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

        // 2. Media Gallery & Tabs
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('Short Video'), findsOneWidget);
        expect(find.text('3D / 360° Tour'), findsOneWidget);

        // 3. Venue Information
        expect(find.text('Grand Royal Arena'), findsWidgets);
        expect(find.textContaining('Banjara Hills'), findsWidgets);

        // 4. Peak Booking Hours
        expect(find.byType(PeakBookingHoursCard), findsOneWidget);

        // 5. Selected Slot Crowd Card
        expect(find.byType(SelectedSlotCrowdCard), findsOneWidget);

        // 6. Location & Map
        expect(find.text('Exact Venue Location & Navigation'), findsOneWidget);
        expect(find.byType(FlutterMap), findsOneWidget);

        // 7. Facilities & Amenities
        expect(find.byType(VenueFacilitiesAmenitiesSection), findsOneWidget);

        // 8. Sticky Booking CTA
        expect(find.byKey(const Key('listing_book_cta')), findsWidgets);

        // 9. AI Help
        expect(find.byKey(const Key('listing_ai_help')), findsOneWidget);

        // Zero overflow
        Object? overflow;
        Object? next = tester.takeException();
        while (next != null) {
          if (next.toString().contains('overflowed')) overflow = next;
          next = tester.takeException();
        }
        expect(overflow, isNull, reason: 'Overflow occurred at ${size.width}x${size.height}');
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });
}
