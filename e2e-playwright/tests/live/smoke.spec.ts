import { Ids, Tab } from '../../support/ids';
import {
  LIVE_EVENT_TYPE,
  bookingIdFromUrl,
  guardBackend,
  isoDate,
  liveConfig,
  pickLiveTarget,
  typeSecret,
} from '../../support/live';
import { expect, test } from '../../support/test';

/**
 * Phase 3 live DEV smoke (E2E_MODE=live only). The DEV web build against
 * the DEV Supabase project, signed in as the DEV customer. It takes one
 * short-lived hold on a seeded venue and never pays, cancels or deletes:
 * the server expires the hold after about 10 minutes.
 */
test.describe('live DEV smoke', () => {
  test(
    'sign in, search, venue, availability, hold, history, sign out',
    { tag: ['@live', '@smoke', '@critical', '@auth', '@booking'] },
    async ({ app, page, request }) => {
      const cfg = liveConfig();
      const verifyBackend = await guardBackend(page);
      const target = await pickLiveTarget(request, cfg);

      // Sign in as the DEV customer.
      await app.open('/login');
      await typeSecret(app, Ids.loginEmail, cfg.email);
      await typeSecret(app, Ids.loginPassword, cfg.password);
      await app.tap(Ids.loginSubmit);
      await app.waitFor(Ids.nav(Tab.home));

      // Search, then open the seeded venue.
      await app.tap(Ids.nav(Tab.search));
      await app.fill(Ids.searchInput, target.venue.name);
      await page.keyboard.press('Enter');
      await app.tap(Ids.venueCard(target.venue.id));
      await app.waitFor(Ids.bookNow);
      await app.tap(Ids.bookNow);

      // Availability on the chosen date, then take the hold.
      await app.waitFor(Ids.bookingDate(isoDate(new Date())));
      await app.tap(Ids.bookingDate(target.isoDate));
      await app.waitFor(Ids.slot(target.venue.slotId));
      await app.fill(Ids.bookingEventType, LIVE_EVENT_TYPE);
      await app.tap(Ids.slot(target.venue.slotId));
      await app.tap(Ids.bookingConfirm);
      await app.tapIfShown(Ids.bookingConfirmDialog);
      await app.waitFor(Ids.checkoutSummary);
      const bookingId = bookingIdFromUrl(page.url());

      // Back to the shell; booking history lists the new booking.
      for (let i = 0; i < 5 && !(await app.byId(Ids.nav(Tab.bookings)).first().isVisible()); i++) {
        await app.back();
      }
      await app.tap(Ids.nav(Tab.bookings));
      await app.waitFor(Ids.bookingHistory);
      await app.reveal(Ids.bookingCard(bookingId));
      const held = app.byId(Ids.bookingStatus(bookingId, 'held'));
      const pending = app.byId(Ids.bookingStatus(bookingId, 'pending'));
      await expect(held.or(pending).first()).toBeVisible();

      // Sign out returns to sign-in.
      await app.tap(Ids.nav(Tab.profile));
      await app.reveal(Ids.logout);
      await app.tap(Ids.logout);
      await app.waitFor(Ids.loginSubmit);

      verifyBackend();
    },
  );
});
