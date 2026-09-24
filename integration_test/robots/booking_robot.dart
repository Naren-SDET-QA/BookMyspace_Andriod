import 'package:bookmyspace/core/widgets/test_id.dart';

import 'base_robot.dart';

class BookingRobot extends BaseRobot {
  BookingRobot(super.tester);

  Future<void> expectSlotPicker() => waitFor(E2eIds.slotPicker);

  /// Function-hall bookings require an event type (name and phone are
  /// pre-filled from the signed-in profile).
  Future<void> enterEventType(String eventType) =>
      enterText(E2eIds.bookingEventType, eventType);

  Future<void> selectSlot(String slotId) => tap(E2eIds.slot(slotId));

  /// Confirms the selected slot. The summary dialog is shown in standard
  /// mode and skipped in quick-booking mode, so it is tapped only if shown.
  Future<void> confirm() async {
    await tap(E2eIds.bookingConfirm);
    await tapIfShown(E2eIds.bookingConfirmDialog);
  }

  /// A held booking opens checkout with its summary.
  Future<void> expectCheckout() => waitFor(E2eIds.checkoutSummary);

  Future<void> expectHistoryCard(String bookingId) async {
    await waitFor(E2eIds.bookingHistory);
    await waitFor(E2eIds.bookingCard(bookingId));
  }

  Future<void> cancel(String bookingId) async {
    await tap(E2eIds.bookingCancel(bookingId));
    await tap(E2eIds.bookingCancelConfirm);
  }
}
