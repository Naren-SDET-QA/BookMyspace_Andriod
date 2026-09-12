import 'dart:convert';

import '../../../core/errors/app_exceptions.dart';
import '../domain/checkout_service.dart';
import 'web_razorpay_bridge.dart';

/// Razorpay Standard Checkout for Flutter Web via Checkout.js.
///
/// Never uses a mobile MethodChannel. Client success is not treated as
/// booking confirmation — that stays with the webhook.
class WebRazorpayCheckoutService implements CheckoutService {
  CheckoutResponse? _lastResponse;

  @override
  CheckoutResponse? get lastResponse => _lastResponse;

  @override
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
  }) async {
    if (orderId.trim().isEmpty || amount <= 0) {
      throw const ValidationException(
        'The payment order is invalid.',
        code: 'invalid_payment_order',
      );
    }
    if (keyId.trim().isEmpty || keyId.contains('PLACEHOLDER')) {
      throw const ConfigurationException(
        'Razorpay checkout is not configured. Add the public test key at build time.',
        code: 'razorpay_not_configured',
      );
    }
    if (!WebRazorpayBridge.isAvailable) {
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.failed,
        orderId: orderId,
        errorCode: 'web_checkout_unavailable',
        errorMessage: 'Razorpay Checkout.js is not available in this browser.',
      );
      return CheckoutResult.failed;
    }

    final options = <String, dynamic>{
      'key': keyId,
      'amount': (amount * 100).round(),
      'currency': currency,
      'name': 'BookMySpace',
      'description':
          'Booking Reservation #${bookingRef ?? orderId.takeLast(6)}',
      'order_id': orderId,
      'theme': {'color': '#00C9A7'},
      'prefill': {
        if (customerName != null && customerName.isNotEmpty)
          'name': customerName,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'email': customerEmail,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'contact': customerPhone,
      },
      'notes': {
        'order_id': orderId,
        if (bookingRef != null) 'booking_ref': bookingRef,
        if (venueName != null && venueName.isNotEmpty) 'venue': venueName,
        'platform': 'web',
        ...?notes,
      },
      'modal': {'escape': true, 'backdropclose': false},
    };

    try {
      final raw = await WebRazorpayBridge.openCheckout(jsonEncode(options));
      return _mapResponse(raw, orderId);
    } catch (error) {
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.failed,
        orderId: orderId,
        errorCode: 'checkout_error',
        errorMessage: 'Payment could not be started. Please try again.',
      );
      return CheckoutResult.failed;
    }
  }

  CheckoutResult _mapResponse(Map<String, dynamic> raw, String orderId) {
    final status = raw['status']?.toString().toLowerCase();
    if (status == 'success') {
      final paymentId = raw['paymentId']?.toString() ??
          raw['razorpay_payment_id']?.toString();
      if (paymentId == null || paymentId.isEmpty) {
        _lastResponse = CheckoutResponse(
          result: CheckoutResult.failed,
          orderId: orderId,
          errorCode: 'missing_payment_reference',
          errorMessage: 'The payment provider returned no payment reference.',
        );
        return CheckoutResult.failed;
      }
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.paid,
        paymentId: paymentId,
        orderId: raw['orderId']?.toString() ?? orderId,
        signature: raw['signature']?.toString() ??
            raw['razorpay_signature']?.toString(),
      );
      return CheckoutResult.paid;
    }
    if (status == 'cancelled') {
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.cancelled,
        orderId: orderId,
        errorMessage:
            raw['message']?.toString() ?? 'Payment dismissed by user.',
      );
      return CheckoutResult.cancelled;
    }
    _lastResponse = CheckoutResponse(
      result: CheckoutResult.failed,
      orderId: orderId,
      errorCode: raw['errorCode']?.toString() ?? 'ERR_PAYMENT_FAILED',
      errorMessage:
          raw['message']?.toString() ?? 'Payment could not be completed.',
    );
    return CheckoutResult.failed;
  }
}

extension on String {
  String takeLast(int n) {
    if (length <= n) return this;
    return substring(length - n);
  }
}
