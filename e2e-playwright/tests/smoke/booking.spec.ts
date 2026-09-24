import { Fixtures } from '../../support/fixtures';
import { Ids, Tab } from '../../support/ids';
import { test } from '../../support/test';

test.describe('booking (mock)', () => {
  test('booking an available slot creates a held booking', { tag: ['@smoke', '@critical', '@booking'] }, async ({ app }) => {
    await app.open(`/venues/${Fixtures.venueId}`, 'signedIn');
    await app.tap(Ids.bookNow);
    await app.expectShown(Ids.slotPicker);
    await app.fill(Ids.bookingEventType, Fixtures.eventType);
    await app.tap(Ids.slot(Fixtures.availableSlotId));
    await app.tap(Ids.bookingConfirm);
    await app.tapIfShown(Ids.bookingConfirmDialog);
    // A held booking opens checkout with its summary.
    await app.expectShown(Ids.checkoutSummary);
  });

  test('booking history lists existing bookings', { tag: ['@smoke', '@booking'] }, async ({ app }) => {
    await app.open('/home', 'withBookings');
    await app.tap(Ids.nav(Tab.bookings));
    await app.expectShown(Ids.bookingHistory);
    await app.expectShown(Ids.bookingCard(Fixtures.seededBookingId));
  });
});
