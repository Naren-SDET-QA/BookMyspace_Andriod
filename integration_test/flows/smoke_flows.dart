import 'package:bookmyspace/core/widgets/test_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../robots/auth_robot.dart';
import '../robots/booking_robot.dart';
import '../robots/navigation_robot.dart';
import '../robots/search_robot.dart';
import '../robots/venue_robot.dart';
import '../support/e2e_env.dart';
import '../support/e2e_fixtures.dart';
import '../support/e2e_harness.dart';
import '../support/mock_backend.dart';

/// Phase 1 mocked smoke flows. Deterministic, no Supabase, PR-safe.
void registerMockSmokeFlows() {
  e2eFlow(
    'app launch shows sign-in when signed out',
    {E2eTags.smoke, E2eTags.critical, E2eTags.auth},
    (tester) async {
      await pumpMockApp(tester, MockScenario.signedOut);
      await AuthRobot(tester).expectSignInScreen();
    },
  );

  e2eFlow(
    'email/password sign-in lands on the home shell',
    {E2eTags.smoke, E2eTags.critical, E2eTags.auth},
    (tester) async {
      await pumpMockApp(tester, MockScenario.signedOut);
      final auth = AuthRobot(tester);
      await auth.expectSignInScreen();
      await auth.signInWithPassword(
        E2eFixtures.customer.email,
        E2eFixtures.mockPassword,
      );
      await NavigationRobot(tester).expectSignedInShell();
    },
  );

  e2eFlow(
    'email OTP sign-in lands on the home shell',
    {E2eTags.smoke, E2eTags.auth},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.signedOut);
      final auth = AuthRobot(tester);
      await auth.requestEmailOtp(E2eFixtures.customer.email);
      await auth.submitOtp(E2eFixtures.mockOtp);
      await NavigationRobot(tester).expectSignedInShell();
      expect(backend.auth.verifyCount, 1);
    },
  );

  e2eFlow(
    'sign-out returns to sign-in',
    {E2eTags.smoke, E2eTags.auth},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.signedIn);
      await NavigationRobot(tester).open(ShellTab.profile);
      final auth = AuthRobot(tester);
      await auth.signOut();
      await auth.expectSignInScreen();
      expect(backend.auth.currentUser, isNull);
    },
  );

  e2eFlow(
    'bottom navigation reaches search, bookings, profile and home',
    {E2eTags.smoke},
    (tester) async {
      await pumpMockApp(tester, MockScenario.signedIn);
      final nav = NavigationRobot(tester);
      await nav.expectSignedInShell();
      await nav.open(ShellTab.search);
      await SearchRobot(tester).waitFor(E2eIds.searchInput);
      await nav.open(ShellTab.bookings);
      await nav.open(ShellTab.profile);
      await AuthRobot(tester).reveal(E2eIds.logout);
      await nav.open(ShellTab.home);
    },
  );

  e2eFlow(
    'search finds a venue and opens its details',
    {E2eTags.smoke, E2eTags.critical},
    (tester) async {
      await pumpMockApp(tester, MockScenario.signedIn);
      await NavigationRobot(tester).open(ShellTab.search);
      final search = SearchRobot(tester);
      await search.search(E2eFixtures.venueSearchQuery);
      await search.openVenue(E2eFixtures.venueId);
      await VenueRobot(tester).expectDetails();
    },
  );

  e2eFlow(
    'booking an available slot creates a held booking',
    {E2eTags.smoke, E2eTags.critical, E2eTags.booking},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.signedIn,
        initialLocation: '/v1/venues/${E2eFixtures.venueId}',
      );
      await VenueRobot(tester).startBooking();
      final booking = BookingRobot(tester);
      await booking.expectSlotPicker();
      await booking.enterEventType(E2eFixtures.eventType);
      await booking.selectSlot(E2eFixtures.availableSlotId);
      await booking.confirm();
      await booking.expectCheckout();
      expect(backend.booking.lastAcquiredVenueId, E2eFixtures.venueId);
      expect(backend.booking.lastAcquiredSlotId, E2eFixtures.availableSlotId);
      expect(backend.booking.createdBooking, isNotNull);
    },
  );

  e2eFlow(
    'booking history lists existing bookings',
    {E2eTags.smoke, E2eTags.booking},
    (tester) async {
      await pumpMockApp(tester, MockScenario.withBookings);
      await NavigationRobot(tester).open(ShellTab.bookings);
      await BookingRobot(
        tester,
      ).expectHistoryCard(E2eFixtures.seededBookingId);
    },
  );
}
