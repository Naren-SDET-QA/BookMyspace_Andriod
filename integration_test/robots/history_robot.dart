import 'package:bookmyspace/core/widgets/test_id.dart';

import 'base_robot.dart';

/// Customer booking history (Bookings tab): tabs, status, card actions.
class HistoryRobot extends BaseRobot {
  HistoryRobot(super.tester);

  Future<void> expectHistory() => waitFor(E2eIds.bookingHistory);

  Future<void> openUpcoming() => tap(E2eIds.bookingsTabUpcoming);

  Future<void> openCompleted() => tap(E2eIds.bookingsTabCompleted);

  Future<void> openCancelled() => tap(E2eIds.bookingsTabCancelled);

  /// The booking's card is listed with exactly this backend status.
  Future<void> expectStatus(String bookingId, String dbStatus) async {
    await reveal(E2eIds.bookingCard(bookingId));
    await waitFor(E2eIds.bookingStatus(bookingId, dbStatus));
  }

  Future<void> pay(String bookingId) async {
    await reveal(E2eIds.bookingPay(bookingId));
    await tap(E2eIds.bookingPay(bookingId));
  }

  Future<void> cancel(String bookingId) async {
    await reveal(E2eIds.bookingCancel(bookingId));
    await tap(E2eIds.bookingCancel(bookingId));
    await tap(E2eIds.bookingCancelConfirm);
  }

  Future<void> requestRefund(String bookingId) async {
    await reveal(E2eIds.bookingRefund(bookingId));
    await tap(E2eIds.bookingRefund(bookingId));
    await tap(E2eIds.bookingRefundConfirm);
  }
}
