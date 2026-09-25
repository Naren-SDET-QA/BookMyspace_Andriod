import 'package:bookmyspace/core/router/app_router.dart';
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

/// Phase 4 live DEV booking lifecycle: customer cancellation and server hold
/// expiry, on seeded DEV venues, signed in as the DEV customer.
///
/// Each flow takes one hold of its own. Cancellation is the customer's own
/// UI action; expiry is left entirely to the server job. Neither flow writes
/// anything the app would not write for a real customer.
void registerLiveBookingLifecycleFlows() {
  e2eFlow(
    'live DEV: customer cancels a held booking',
    {E2eTags.live, E2eTags.booking, E2eTags.cancellation},
    (tester) async {
      const wait = E2eLive.networkTimeout;
      final hold = await _signInAndHold(tester);
      final nav = NavigationRobot(tester);
      final history = HistoryRobot(tester);

      // The held booking is listed as upcoming.
      await nav.returnToShell();
      await nav.open(ShellTab.bookings);
      await history.waitFor(E2eIds.bookingHistory, timeout: wait);
      await history.expectAnyStatus(
        hold.bookingId,
        _heldStatuses,
        timeout: wait,
      );

      // Cancel it through the customer's own history action.
      await history.cancel(hold.bookingId);
      await history.waitForAbsence(
        E2eIds.bookingCard(hold.bookingId),
        timeout: wait,
      );
      await history.openCancelled();
      await history.expectAnyStatus(
        hold.bookingId,
        const ['cancelled'],
        timeout: wait,
      );
      history.expectNotShown(E2eIds.bookingCancel(hold.bookingId));
      expect(await liveBookingStatus(hold.bookingId), 'cancelled');

      await nav.open(ShellTab.profile);
      final auth = AuthRobot(tester);
      await auth.signOut();
      await auth.expectSignInScreen();
    },
  );

  e2eFlow(
    'live DEV: an unpaid hold expires on the server and frees the slot',
    {E2eTags.live, E2eTags.booking, E2eTags.slow},
    (tester) async {
      const wait = E2eLive.networkTimeout;
      final hold = await _signInAndHold(tester);
      expect((await liveHoldOf(hold.bookingId)).status, 'active');
      expect(await isLiveSlotAvailable(hold.target), isFalse);

      // No payment and no cancellation: only the server job may release it.
      await NavigationRobot(tester).returnToShell();
      await waitForLiveHoldExpiry(tester, hold.bookingId);
      expect(await isLiveSlotAvailable(hold.target), isTrue);

      // A fresh app (nothing cached) lists the booking as cancelled.
      await repumpLiveApp(tester, AppRoutes.bookings);
      final history = HistoryRobot(tester);
      await history.waitFor(E2eIds.bookingHistory, timeout: wait);
      await history.openCancelled();
      await history.expectAnyStatus(
        hold.bookingId,
        const ['cancelled'],
        timeout: wait,
      );

      await NavigationRobot(tester).open(ShellTab.profile);
      final auth = AuthRobot(tester);
      await auth.signOut();
      await auth.expectSignInScreen();
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

const _heldStatuses = ['held', 'pending'];

/// Signs in as the DEV customer and takes one hold on a free seeded slot,
/// the same journey as the Phase 3 smoke. Returns once checkout shows it
/// and the booking row has been checked on the server.
Future<({String bookingId, LiveTarget target})> _signInAndHold(
  WidgetTester tester,
) async {
  const wait = E2eLive.networkTimeout;
  await pumpLiveApp(tester);
  final target = await pickLiveTarget();
  final auth = AuthRobot(tester);
  final nav = NavigationRobot(tester);

  await auth.expectSignInScreen();
  await auth.signInWithPassword(E2eEnv.userEmail, E2eEnv.userPassword);
  await nav.waitFor(E2eIds.nav(ShellTab.home), timeout: wait);
  final userId = E2eLive.client.auth.currentUser?.id;
  expect(userId, isNotNull, reason: 'sign-in did not create a session');

  await nav.open(ShellTab.search);
  final search = SearchRobot(tester);
  await search.waitFor(E2eIds.searchInput, timeout: wait);
  await search.search(target.venue.name);
  await search.waitFor(E2eIds.venueCard(target.venue.id), timeout: wait);
  await search.openVenue(target.venue.id);
  final venue = VenueRobot(tester);
  await venue.waitFor(E2eIds.bookNow, timeout: wait);
  await venue.startBooking();

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
  return (bookingId: bookingId, target: target);
}
