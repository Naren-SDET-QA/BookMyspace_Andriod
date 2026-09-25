import { Ids } from '../../support/ids';
import {
  backToShell,
  guardBackend,
  isSlotAvailable,
  liveConfig,
  pickLiveTarget,
  signInAndHold,
  signOut,
} from '../../support/live';
import { expect, test } from '../../support/test';

/**
 * Phase 4 live DEV hold expiry (E2E_MODE=live only, about 11–13 minutes).
 * The customer takes a hold and does nothing: the server job
 * (expire-booking-holds, every minute) must expire the hold after 10 minutes,
 * cancel its draft booking and free the slot. Nothing is written by the test.
 */
test.describe('live DEV hold expiry', () => {
  test(
    'an unpaid hold expires on the server and frees the slot',
    { tag: ['@live', '@booking', '@slow'] },
    async ({ app, page, request }) => {
      test.setTimeout(20 * 60_000);
      const cfg = liveConfig();
      const verifyBackend = await guardBackend(page);
      const target = await pickLiveTarget(request, cfg);
      const bookingId = await signInAndHold(app, page, cfg, target);
      expect(await isSlotAvailable(request, cfg, target)).toBe(false);

      // No payment and no cancellation: only the server job may release it.
      await backToShell(app);
      await expect
        .poll(() => isSlotAvailable(request, cfg, target), {
          message: 'the hold was not released by the expire-booking-holds job within 14 minutes',
          timeout: 14 * 60_000,
          intervals: [15_000],
        })
        .toBe(true);

      // A fresh app load (same session) lists the booking as cancelled.
      await app.open('/bookings');
      await app.waitFor(Ids.bookingHistory);
      await app.tap(Ids.bookingsTabCancelled);
      await app.reveal(Ids.bookingStatus(bookingId, 'cancelled'));

      await signOut(app);
      verifyBackend();
    },
  );
});
