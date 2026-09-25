import { Fixtures, Status } from '../../support/fixtures';
import { Ids } from '../../support/ids';
import { test } from '../../support/test';

test.describe('owner (mock)', () => {
  test.beforeEach(async ({ app }) => {
    await app.open('/owner', 'ownerSignedIn');
    await app.expectShown(Ids.ownerActionBookings);
  });

  test('owner approves a booking awaiting sign-off', { tag: ['@critical', '@owner', '@booking'] }, async ({ app }) => {
    const id = Fixtures.approvalBookingId;
    await app.tap(Ids.ownerActionBookings);
    await app.expectShown(Ids.bookingStatus(id, Status.pendingOwnerApproval));
    await app.tap(Ids.ownerBookingApprove(id));
    await app.tap(Ids.ownerDecisionConfirm);
    await app.expectShown(Ids.bookingStatus(id, Status.confirmed));
    await app.expectNotShown(Ids.ownerBookingApprove(id));
    await app.expectNotShown(Ids.ownerBookingReject(id));
  });

  test('owner rejects a booking awaiting sign-off', { tag: ['@owner', '@booking'] }, async ({ app }) => {
    const id = Fixtures.approvalBookingId;
    await app.tap(Ids.ownerActionBookings);
    await app.tap(Ids.ownerBookingReject(id));
    await app.tap(Ids.ownerDecisionConfirm);
    await app.expectShown(Ids.bookingStatus(id, Status.rejected));
    await app.expectNotShown(Ids.ownerBookingApprove(id));
    await app.expectShown(Ids.bookingStatus(Fixtures.confirmedBookingId, Status.confirmed));
  });

  test('owner unpublishes and republishes a listing', { tag: ['@owner'] }, async ({ app }) => {
    const venue = Fixtures.venueId;
    await app.tap(Ids.ownerActionVenues);
    await app.expectShown(Ids.ownerVenueState(venue, 'published'));
    await app.tap(Ids.ownerVenuePublish(venue));
    await app.expectShown(Ids.ownerVenueState(venue, 'unpublished'));
    await app.tap(Ids.ownerVenuePublish(venue));
    await app.expectShown(Ids.ownerVenueState(venue, 'published'));
  });

  test('owner adds a time slot and deactivates it', { tag: ['@owner'] }, async ({ app }) => {
    const label = Fixtures.newSlotLabel;
    await app.tap(Ids.ownerActionVenues);
    await app.tap(Ids.ownerVenueAvailability(Fixtures.venueId));
    await app.reveal(Ids.availabilityAddSlot);
    await app.tap(Ids.availabilityAddSlot);
    await app.fill(Ids.availabilitySlotLabel, label);
    await app.fill(Ids.availabilitySlotStart, '10:00');
    await app.fill(Ids.availabilitySlotEnd, '12:00');
    await app.fill(Ids.availabilitySlotPrice, '5000');
    await app.tap(Ids.availabilitySlotSave);
    await app.reveal(Ids.availabilitySlot(label));
    await app.expectShown(Ids.availabilitySlotState(label, 'active'));
    await app.tap(Ids.availabilitySlot(label));
    await app.expectShown(Ids.availabilitySlotState(label, 'inactive'));
  });

  test('owner cannot save a time slot that ends before it starts', { tag: ['@owner', '@negative'] }, async ({ app }) => {
    await app.tap(Ids.ownerActionVenues);
    await app.tap(Ids.ownerVenueAvailability(Fixtures.venueId));
    await app.reveal(Ids.availabilityAddSlot);
    await app.tap(Ids.availabilityAddSlot);
    await app.fill(Ids.availabilitySlotLabel, Fixtures.newSlotLabel);
    await app.fill(Ids.availabilitySlotStart, '12:00');
    await app.fill(Ids.availabilitySlotEnd, '10:00');
    await app.fill(Ids.availabilitySlotPrice, '5000');
    await app.tap(Ids.availabilitySlotSave);
    await app.expectShown(Ids.availabilitySlotSave);
    await app.expectNotShown(Ids.availabilitySlot(Fixtures.newSlotLabel));
  });
});
