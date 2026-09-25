import { Fixtures, Status } from '../../support/fixtures';
import { Ids } from '../../support/ids';
import { test } from '../../support/test';

test.describe('cancellation & refund (mock)', () => {
  test('customer cancels a pending booking', { tag: ['@critical', '@booking'] }, async ({ app }) => {
    const id = Fixtures.seededBookingId;
    await app.open('/bookings', 'withBookings');
    await app.expectShown(Ids.bookingStatus(id, Status.pending));
    await app.reveal(Ids.bookingCancel(id));
    await app.tap(Ids.bookingCancel(id));
    await app.tap(Ids.bookingCancelConfirm);
    await app.expectNotShown(Ids.bookingCard(id));
    await app.tap(Ids.bookingsTabCancelled);
    await app.expectShown(Ids.bookingStatus(id, Status.cancelled));
    await app.expectNotShown(Ids.bookingCancel(id));
    await app.expectNotShown(Ids.bookingPay(id));
  });

  test('a cancellation rejected by the server keeps the booking', { tag: ['@booking', '@negative'] }, async ({ app }) => {
    const id = Fixtures.seededBookingId;
    await app.open('/bookings', 'cancelFails');
    await app.reveal(Ids.bookingCancel(id));
    await app.tap(Ids.bookingCancel(id));
    await app.tap(Ids.bookingCancelConfirm);
    await app.expectShown(Ids.bookingStatus(id, Status.pending));
    await app.expectShown(Ids.bookingCancel(id));
  });

  test('customer requests a refund for a confirmed booking', { tag: ['@booking', '@payment'] }, async ({ app }) => {
    const id = Fixtures.confirmedBookingId;
    await app.open('/bookings', 'confirmedBooking');
    await app.expectShown(Ids.bookingStatus(id, Status.confirmed));
    await app.expectNotShown(Ids.bookingCancel(id));
    await app.reveal(Ids.bookingRefund(id));
    await app.tap(Ids.bookingRefund(id));
    await app.tap(Ids.bookingRefundConfirm);
    await app.expectNotShown(Ids.bookingRefundConfirm);
    // A refund request is not a refund: no client-side "refunded" state.
    await app.expectShown(Ids.bookingStatus(id, Status.confirmed));
  });
});

test.describe('failures, retries & duplicate submission (mock)', () => {
  test('slot availability failure recovers on retry', { tag: ['@booking', '@negative'] }, async ({ app }) => {
    await app.open(`/venues/${Fixtures.venueId}`, 'flakyAvailability');
    await app.tap(Ids.bookNow);
    await app.tap(Ids.errorRetry);
    await app.expectShown(Ids.slotPicker);
    await app.expectShown(Ids.slot(Fixtures.availableSlotId));
  });

  test('persistent availability failure keeps offering retry', { tag: ['@booking', '@negative'] }, async ({ app }) => {
    await app.open(`/venues/${Fixtures.venueId}`, 'networkFailure');
    await app.tap(Ids.bookNow);
    await app.tap(Ids.errorRetry);
    await app.expectShown(Ids.errorRetry);
    await app.expectNotShown(Ids.slotPicker);
    await app.expectNotShown(Ids.bookingConfirm);
  });

  test('a slot taken by someone else is reported and nothing is booked', { tag: ['@booking', '@negative'] }, async ({ app }) => {
    await app.open(`/venues/${Fixtures.venueId}`, 'slotTaken');
    await app.tap(Ids.bookNow);
    await app.fill(Ids.bookingEventType, Fixtures.eventType);
    await app.tap(Ids.slot(Fixtures.availableSlotId));
    await app.tap(Ids.bookingConfirm);
    await app.tapIfShown(Ids.bookingConfirmDialog);
    await app.expectShown(Ids.slotPicker);
    await app.expectNotShown(Ids.checkoutSummary);
  });

  test('an unavailable slot cannot be booked', { tag: ['@booking', '@negative'] }, async ({ app }) => {
    await app.open(`/venues/${Fixtures.venueId}`, 'signedIn');
    await app.tap(Ids.bookNow);
    // Booked slot: its tile has no onTap (booking_screen `_SlotTile`).
    await app.tapExpectingNoEffect(Ids.slot(Fixtures.unavailableSlotId));
    await app.expectNotShown(Ids.bookingConfirm);
  });

  test('a second confirm while the hold is in flight takes one hold', { tag: ['@booking', '@negative'] }, async ({ app, page }) => {
    await app.open(`/venues/${Fixtures.venueId}`, 'slowHold');
    await app.tap(Ids.bookNow);
    await app.fill(Ids.bookingEventType, Fixtures.eventType);
    await app.tap(Ids.slot(Fixtures.availableSlotId));
    await app.tap(Ids.bookingConfirm);
    await app.tapIfShown(Ids.bookingConfirmDialog, 500);
    // Hold request in flight (1.5 s): press confirm again.
    // Confirm is disabled while `confirming` (booking_screen confirm bar).
    await app.tapExpectingNoEffect(Ids.bookingConfirm);
    await page.waitForTimeout(300);
    await app.expectNotShown(Ids.bookingConfirmDialog);
    await app.expectShown(Ids.checkoutSummary);
    // Exactly one checkout route was pushed: one back press leaves it.
    await app.back();
    await app.expectNotShown(Ids.checkoutSummary);
    await app.expectShown(Ids.slotPicker);
  });
});
