import { Ids, Tab } from '../../support/ids';
import { backToShell, guardBackend, liveConfig, pickLiveTarget, signInAndHold, signOut } from '../../support/live';
import { test } from '../../support/test';

/**
 * Phase 4 live DEV cancellation (E2E_MODE=live only). The customer cancels
 * their own held booking from history. Cancelling does not release the hold,
 * so the slot stays taken until the server expires the hold (~10 min).
 */
test.describe('live DEV cancellation', () => {
  test(
    'customer cancels a held booking',
    { tag: ['@live', '@booking', '@cancellation'] },
    async ({ app, page, request }) => {
      test.setTimeout(5 * 60_000);
      const cfg = liveConfig();
      const verifyBackend = await guardBackend(page);
      const target = await pickLiveTarget(request, cfg);
      const bookingId = await signInAndHold(app, page, cfg, target);

      // The held booking is listed as upcoming.
      await backToShell(app);
      await app.tap(Ids.nav(Tab.bookings));
      await app.waitFor(Ids.bookingHistory);
      await app.reveal(Ids.bookingCard(bookingId));

      // Cancel it through the customer's own history action.
      await app.reveal(Ids.bookingCancel(bookingId));
      await app.tap(Ids.bookingCancel(bookingId));
      await app.tap(Ids.bookingCancelConfirm);
      await app.expectNotShown(Ids.bookingCard(bookingId));
      await app.tap(Ids.bookingsTabCancelled);
      await app.reveal(Ids.bookingStatus(bookingId, 'cancelled'));
      await app.expectNotShown(Ids.bookingCancel(bookingId));

      await signOut(app);
      verifyBackend();
    },
  );
});
