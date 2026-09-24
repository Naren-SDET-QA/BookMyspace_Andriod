import 'package:bookmyspace/core/widgets/test_id.dart';

import 'base_robot.dart';

/// Checkout / payment screen. The Razorpay SDK is never opened: mock mode
/// injects `E2eCheckoutService`, which plays back scripted outcomes.
class PaymentRobot extends BaseRobot {
  PaymentRobot(super.tester);

  /// The payment screen can take one full verification poll window
  /// (about 11 status reads, 2 s apart) before it settles on "pending".
  static const verificationWindow = Duration(seconds: 45);

  Future<void> expectCheckout() => waitFor(E2eIds.checkoutSummary);

  Future<void> chooseOnline() => tap(E2eIds.paymentMethodOnline);

  Future<void> choosePayAtVenue() => tap(E2eIds.paymentMethodVenue);

  Future<void> pay() => tap(E2eIds.paymentPay);

  Future<void> expectVerifying() => waitFor(E2eIds.paymentVerifying);

  Future<void> expectPending({Duration timeout = verificationWindow}) =>
      waitFor(E2eIds.paymentPending, timeout: timeout);

  Future<void> expectSuccess({Duration timeout = verificationWindow}) =>
      waitFor(E2eIds.bookingSuccess, timeout: timeout);

  Future<void> expectError() => waitFor(E2eIds.paymentError);

  Future<void> expectMessage() => waitFor(E2eIds.paymentMessage);

  Future<void> expectHoldExpired() => waitFor(E2eIds.holdExpired);

  Future<void> done() => tap(E2eIds.paymentDone);
}
