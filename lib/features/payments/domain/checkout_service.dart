/// Outcome of invoking a payment checkout interface.
enum CheckoutResult {
  paid,
  failed,
  cancelled;

  bool get isPaid => this == CheckoutResult.paid;
  bool get isFailed => this == CheckoutResult.failed;
  bool get isCancelled => this == CheckoutResult.cancelled;
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
  /// Opens the checkout flow with the given Razorpay order parameters.
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
