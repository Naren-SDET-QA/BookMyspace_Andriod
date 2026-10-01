import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/errors/app_exceptions.dart';
import '../domain/checkout_service.dart';

/// Real Razorpay Checkout implementation (Android/iOS).
///
/// Requires a live test key: when [ConfigurationException] is thrown the
/// caller should surface a friendly message instead of crashing.
class RazorpayCheckoutService implements CheckoutService {
  CheckoutResponse? _lastResponse;

  @override
  CheckoutResponse? get lastResponse => _lastResponse;

  @override
  CheckoutSuccessDetails? get lastSuccessDetails {
    final response = _lastResponse;
    if (response == null || response.result != CheckoutResult.paid) return null;
    return CheckoutSuccessDetails(
      paymentId: response.paymentId ?? '',
      orderId: response.orderId ?? '',
      signature: response.signature ?? '',
    );
  }

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
    if (keyId.trim().isEmpty || keyId.contains('PLACEHOLDER')) {
      throw const ConfigurationException(
        'Razorpay checkout is not configured. Add a test key to run payments.',
        code: 'razorpay_not_configured',
      );
    }

    final completer = Completer<CheckoutResult>();
    final razorpay = Razorpay();

    void successHandler(PaymentSuccessResponse response) {
      razorpay.clear();
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.paid,
        paymentId: response.paymentId,
        orderId: response.orderId ?? orderId,
        signature: response.signature,
      );
      completer.complete(CheckoutResult.paid);
    }

    void errorHandler(PaymentFailureResponse response) {
      razorpay.clear();
      final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
      _lastResponse = CheckoutResponse(
        result: cancelled ? CheckoutResult.cancelled : CheckoutResult.failed,
        orderId: orderId,
        errorCode: response.code?.toString(),
        errorMessage: response.message,
      );
      completer.complete(
        cancelled ? CheckoutResult.cancelled : CheckoutResult.failed,
      );
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, successHandler);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, errorHandler);
    razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': (amount * 100).round(),
      'currency': currency,
      'name': 'BookMySpace',
      'prefill': const {'contact': '', 'email': ''},
      'theme': const {'color': '#6750A4'},
    });

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        razorpay.clear();
        _lastResponse = CheckoutResponse(
          result: CheckoutResult.timedOut,
          orderId: orderId,
          errorCode: 'checkout_timeout',
          errorMessage: 'Payment checkout timed out.',
        );
        return CheckoutResult.timedOut;
      },
    );
  }
}
