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
/// On iOS and Android, this is backed by the native Razorpay SDK via
/// platform channels. On Web, it invokes the browser-compatible checkout.
abstract interface class CheckoutService {
  /// Opens the checkout flow with the given Razorpay order parameters.
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
  });

  /// The most recent detailed response from the checkout engine.
  CheckoutResponse? get lastResponse => null;
}
