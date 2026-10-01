/// Outcome of invoking a payment checkout interface.
enum CheckoutResult {
  paid,
  failed,

  /// The user closed the checkout without completing a payment.
  cancelled,

  /// Checkout did not reach a terminal provider callback before its timeout.
  timedOut;

  bool get isPaid => this == CheckoutResult.paid;
  bool get isFailed => this == CheckoutResult.failed;
  bool get isCancelled => this == CheckoutResult.cancelled;
  bool get isTimedOut => this == CheckoutResult.timedOut;
}

/// Provider response captured from a successful checkout.
///
/// This is diagnostic/hand-off metadata only. Server-side webhook processing
/// remains authoritative for payment confirmation.
class CheckoutSuccessDetails {
  const CheckoutSuccessDetails({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  final String paymentId;
  final String orderId;
  final String signature;
}

/// Detailed response from the native Razorpay SDK or Web checkout.
class CheckoutResponse {
  const CheckoutResponse({
    required this.result,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorCode,
    this.errorMessage,
  });

  final CheckoutResult result;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorCode;
  final String? errorMessage;
}

/// Abstract contract for launching payment sheets across platforms.
///
/// Android and iOS use the native Razorpay Standard Checkout SDK.
/// Web uses Razorpay Checkout.js in the browser. The booking/payment
/// state machine above this interface is shared.
abstract interface class CheckoutService {
  CheckoutSuccessDetails? get lastSuccessDetails;

  /// Opens the payment UI for [orderId] and waits for the terminal outcome.
  ///
  /// [amount] is the server-authoritative order amount in major units
  /// (INR rupees). Implementations convert to paise for Razorpay.
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
    String? venueName,
    String? bookingRef,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    Map<String, dynamic>? notes,
  });

  /// The most recent detailed response from the checkout engine.
  CheckoutResponse? get lastResponse;
}
