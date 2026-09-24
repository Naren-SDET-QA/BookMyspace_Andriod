import 'package:bookmyspace/core/widgets/test_id.dart';

import 'base_robot.dart';

/// Owner dashboard, owner bookings, listings and availability.
class OwnerRobot extends BaseRobot {
  OwnerRobot(super.tester);

  /// Owner actions only render once the backend returned an owner profile.
  Future<void> expectDashboard() async {
    await waitFor(E2eIds.ownerDashboard);
    await waitFor(E2eIds.ownerActionBookings);
  }

  Future<void> openBookings() => tap(E2eIds.ownerActionBookings);

  Future<void> openVenues() => tap(E2eIds.ownerActionVenues);

  Future<void> expectBooking(String bookingId, String dbStatus) async {
    await reveal(E2eIds.ownerBookingCard(bookingId));
    await waitFor(E2eIds.bookingStatus(bookingId, dbStatus));
  }

  Future<void> approve(String bookingId) async {
    await reveal(E2eIds.ownerBookingApprove(bookingId));
    await tap(E2eIds.ownerBookingApprove(bookingId));
    await tap(E2eIds.ownerDecisionConfirm);
  }

  Future<void> reject(String bookingId) async {
    await reveal(E2eIds.ownerBookingReject(bookingId));
    await tap(E2eIds.ownerBookingReject(bookingId));
    await tap(E2eIds.ownerDecisionConfirm);
  }

  Future<void> expectVenueState(String venueId, String state) =>
      waitFor(E2eIds.ownerVenueState(venueId, state));

  Future<void> togglePublished(String venueId) =>
      tap(E2eIds.ownerVenuePublish(venueId));

  Future<void> openAvailability(String venueId) =>
      tap(E2eIds.ownerVenueAvailability(venueId));

  /// Opens the add-slot dialog, fills it and presses Save.
  Future<void> addSlot({
    required String label,
    required String start,
    required String end,
    required String price,
  }) async {
    await reveal(E2eIds.availabilityAddSlot);
    await tap(E2eIds.availabilityAddSlot);
    await enterText(E2eIds.availabilitySlotLabel, label);
    await enterText(E2eIds.availabilitySlotStart, start);
    await enterText(E2eIds.availabilitySlotEnd, end);
    await enterText(E2eIds.availabilitySlotPrice, price);
    await tap(E2eIds.availabilitySlotSave);
  }

  Future<void> expectSlot(String label, String state) async {
    await reveal(E2eIds.availabilitySlot(label));
    await waitFor(E2eIds.availabilitySlotState(label, state));
  }

  Future<void> toggleSlot(String label) => tap(E2eIds.availabilitySlot(label));
}
