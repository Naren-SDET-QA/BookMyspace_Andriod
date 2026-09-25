import { Fixtures, Status } from '../../support/fixtures';
import { Ids, Tab } from '../../support/ids';
import { test } from '../../support/test';

/** A capture waits for up to ~11 status polls (2 s apart) before settling. */
const VERIFICATION_WINDOW = 45_000;

test.describe('booking lifecycle & payment (mock)', () => {
  test('lifecycle: hold, pay at venue, owner approves, customer sees confirmed', { tag: ['@critical', '@booking', '@payment', '@owner'] }, async ({ app, page }) => {
    test.setTimeout(180_000);
    const id = Fixtures.firstCreatedBookingId;

    // Customer: find the venue, take a hold, choose pay at venue.
    await app.open('/search', 'signedIn');
    await app.fill(Ids.searchInput, Fixtures.venueSearchQuery);
    await page.keyboard.press('Enter');
    await app.tap(Ids.venueCard(Fixtures.venueId));
    await app.tap(Ids.bookNow);
    await app.fill(Ids.bookingEventType, Fixtures.eventType);
    await app.tap(Ids.slot(Fixtures.availableSlotId));
    await app.tap(Ids.bookingConfirm);
    await app.tapIfShown(Ids.bookingConfirmDialog);
    await app.expectShown(Ids.checkoutSummary);
    await app.tap(Ids.paymentMethodVenue);
    await app.tap(Ids.paymentPay);
    await app.expectShown(Ids.paymentPending);
    await app.expectNotShown(Ids.bookingSuccess);

    // History shows it awaiting the owner.
    await app.tap(Ids.paymentDone);
    await app.tap(Ids.nav(Tab.bookings));
    await app.reveal(Ids.bookingCard(id));
    await app.expectShown(Ids.bookingStatus(id, Status.pendingOwnerApproval));

    // Owner signs in and approves.
    await app.tap(Ids.nav(Tab.profile));
    await app.reveal(Ids.logout);
    await app.tap(Ids.logout);
    await app.fill(Ids.loginEmail, Fixtures.ownerEmail);
    await app.fill(Ids.loginPassword, Fixtures.mockPassword);
    await app.tap(Ids.loginSubmit);
    await app.tap(Ids.nav(Tab.profile));
    await app.reveal(Ids.profileOwnerDashboard);
    await app.tap(Ids.profileOwnerDashboard);
    await app.tap(Ids.ownerActionBookings);
    await app.expectShown(Ids.bookingStatus(id, Status.pendingOwnerApproval));
    await app.tap(Ids.ownerBookingApprove(id));
    await app.tap(Ids.ownerDecisionConfirm);
    await app.expectShown(Ids.bookingStatus(id, Status.confirmed));

    // Customer signs back in and sees the confirmation.
    await app.back();
    await app.back();
    await app.tap(Ids.nav(Tab.profile));
    await app.reveal(Ids.logout);
    await app.tap(Ids.logout);
    await app.fill(Ids.loginEmail, Fixtures.customerEmail);
    await app.fill(Ids.loginPassword, Fixtures.mockPassword);
    await app.tap(Ids.loginSubmit);
    await app.tap(Ids.nav(Tab.bookings));
    await app.reveal(Ids.bookingCard(id));
    await app.expectShown(Ids.bookingStatus(id, Status.confirmed));
  });

  test('online payment is captured and awaits owner approval', { tag: ['@critical', '@payment', '@booking'] }, async ({ app }) => {
    await app.open('/bookings', 'withBookings');
    await app.tap(Ids.bookingPay(Fixtures.seededBookingId));
    await app.expectShown(Ids.checkoutSummary);
    await app.tap(Ids.paymentPay);
    await app.expectNotShown(Ids.paymentPay);
    await app.expectShown(Ids.paymentVerifying);
    await app.byId(Ids.paymentPending).first().waitFor({ state: 'visible', timeout: VERIFICATION_WINDOW });
    await app.expectNotShown(Ids.bookingSuccess);
  });

  test('payment approved while verifying shows the booking confirmation', { tag: ['@payment', '@booking'] }, async ({ app }) => {
    await app.open('/bookings', 'payApprovedWhileVerifying');
    await app.tap(Ids.bookingPay(Fixtures.seededBookingId));
    await app.tap(Ids.paymentPay);
    await app.byId(Ids.bookingSuccess).first().waitFor({ state: 'visible', timeout: VERIFICATION_WINDOW });
  });

  test('failed checkout shows an error and never confirms', { tag: ['@payment', '@negative'] }, async ({ app }) => {
    await app.open('/bookings', 'payFails');
    await app.tap(Ids.bookingPay(Fixtures.seededBookingId));
    await app.tap(Ids.paymentPay);
    await app.expectShown(Ids.paymentError);
    await app.expectNotShown(Ids.paymentVerifying);
    await app.expectNotShown(Ids.bookingSuccess);
  });

  test('cancelled checkout can be retried', { tag: ['@payment', '@negative'] }, async ({ app }) => {
    await app.open('/bookings', 'payCancelledThenPaid');
    await app.tap(Ids.bookingPay(Fixtures.seededBookingId));
    await app.tap(Ids.paymentPay);
    await app.expectShown(Ids.paymentMessage);
    await app.tap(Ids.paymentPay);
    await app.byId(Ids.paymentPending).first().waitFor({ state: 'visible', timeout: VERIFICATION_WINDOW });
  });

  test('order creation failure is reported and a retry succeeds', { tag: ['@payment', '@negative'] }, async ({ app }) => {
    const id = Fixtures.seededBookingId;
    await app.open('/bookings', 'orderFailsOnce');
    await app.tap(Ids.bookingPay(id));
    await app.tap(Ids.paymentPay);
    await app.expectShown(Ids.paymentError);
    await app.tap(Ids.paymentDone);
    await app.tap(Ids.bookingPay(id));
    await app.tap(Ids.paymentPay);
    await app.byId(Ids.paymentPending).first().waitFor({ state: 'visible', timeout: VERIFICATION_WINDOW });
  });

  test('an expired hold blocks payment', { tag: ['@payment', '@booking', '@negative'] }, async ({ app }) => {
    await app.open('/bookings', 'staleHold');
    await app.tap(Ids.bookingPay(Fixtures.staleHoldBookingId));
    await app.expectShown(Ids.checkoutSummary);
    await app.expectShown(Ids.holdExpired);
    await app.tap(Ids.paymentPay);
    await app.tap(Ids.paymentMethodVenue);
    await app.tap(Ids.paymentPay);
    await app.expectNotShown(Ids.paymentVerifying);
    await app.expectNotShown(Ids.paymentPending);
    await app.expectShown(Ids.checkoutSummary);
  });
});
