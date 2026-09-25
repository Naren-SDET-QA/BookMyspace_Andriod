import 'package:bookmyspace/core/widgets/test_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../robots/auth_robot.dart';
import '../robots/booking_robot.dart';
import '../robots/history_robot.dart';
import '../robots/navigation_robot.dart';
import '../robots/search_robot.dart';
import '../robots/venue_robot.dart';
import '../support/e2e_env.dart';
import '../support/e2e_harness.dart';
import '../support/e2e_live.dart';

/// Phase 3 live DEV smoke: the production app against the DEV Supabase
/// project, signed in as the DEV customer from dart-defines.
///
/// It takes one short-lived hold on a seeded DEV venue and never pays,
/// cancels or deletes anything: the server expires the hold, and releases
/// its draft booking, after about 10 minutes.
void registerLiveSmokeFlows() {
  e2eFlow(
    'live DEV: sign in, search, venue, availability, hold, history, sign out',
    {
      E2eTags.live,
      E2eTags.smoke,
      E2eTags.critical,
      E2eTags.auth,
      E2eTags.booking,
    },
    (tester) async {
      const wait = E2eLive.networkTimeout;
      await pumpLiveApp(tester);
      final target = await pickLiveTarget();
      final auth = AuthRobot(tester);
      final nav = NavigationRobot(tester);

      // Sign in as the DEV customer.
      await auth.expectSignInScreen();
      await auth.signInWithPassword(E2eEnv.userEmail, E2eEnv.userPassword);
      await nav.waitFor(E2eIds.nav(ShellTab.home), timeout: wait);
      await nav.expectSignedInShell();
      final userId = E2eLive.client.auth.currentUser?.id;
      expect(userId, isNotNull, reason: 'sign-in did not create a session');

      // Search, then open the seeded venue.
      await nav.open(ShellTab.search);
      final search = SearchRobot(tester);
      await search.waitFor(E2eIds.searchInput, timeout: wait);
      await search.search(target.venue.name);
      await search.waitFor(E2eIds.venueCard(target.venue.id), timeout: wait);
      await search.openVenue(target.venue.id);
      final venue = VenueRobot(tester);
      await venue.waitFor(E2eIds.bookNow, timeout: wait);
      await venue.startBooking();

      // Availability on the chosen date, then take the hold.
      final booking = BookingRobot(tester);
      await booking.selectDate(
        target.isoDate,
        anchorIsoDate: e2eIsoDate(DateTime.now()),
        timeout: wait,
      );
      await booking.waitFor(E2eIds.slot(target.venue.slotId), timeout: wait);
      await booking.enterEventType(E2eLiveFixtures.eventType);
      await booking.selectSlot(target.venue.slotId);
      await booking.confirm();
      await booking.waitFor(E2eIds.checkoutSummary, timeout: wait);
      final bookingId = liveBookingIdFromLocation(tester);
      await expectLiveHeldBooking(bookingId, userId: userId!, target: target);

      // Booking history lists the new booking.
      await nav.returnToShell();
      await nav.open(ShellTab.bookings);
      final history = HistoryRobot(tester);
      await history.waitFor(E2eIds.bookingHistory, timeout: wait);
      const heldStatuses = ['held', 'pending'];
      await history.expectAnyStatus(bookingId, heldStatuses, timeout: wait);

      // Sign out ends the session and returns to sign-in.
      await nav.open(ShellTab.profile);
      await auth.signOut();
      await auth.expectSignInScreen();
      expect(E2eLive.client.auth.currentSession, isNull);
    },
  );
}
