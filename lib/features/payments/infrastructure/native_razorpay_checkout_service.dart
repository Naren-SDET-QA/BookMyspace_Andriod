import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/app_exceptions.dart';
import '../domain/checkout_service.dart';

/// Native Razorpay Standard Checkout for Android and iOS.
///
/// Delegates to the platform Razorpay SDK via the
/// `com.bookmyspace.bookmyspace/razorpay_native` MethodChannel.
/// Web uses [WebRazorpayCheckoutService] instead.
class NativeRazorpayCheckoutService implements CheckoutService {
  NativeRazorpayCheckoutService();

  static const MethodChannel _channel =
      MethodChannel('com.bookmyspace.bookmyspace/razorpay_native');

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

    try {
      final payload = <String, dynamic>{
        'keyId': keyId,
        'orderId': orderId,
        'amount': amount,
        'amountInPaise': (amount * 100).round(),
        'currency': currency,
        'name': 'BookMySpace',
        'description':
            'Booking Reservation #${bookingRef ?? orderId.takeLast(6)}',
        if (venueName != null && venueName.isNotEmpty) 'venueName': venueName,
        if (customerName != null && customerName.isNotEmpty)
          'customerName': customerName,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'customerEmail': customerEmail,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customerPhone': customerPhone,
        'themeColor': '#00BFA5',
        'notes': {
          'order_id': orderId,
          if (bookingRef != null) 'booking_ref': bookingRef,
          'platform': defaultTargetPlatform.name,
          ...?notes,
        },
      };

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'openCheckout',
        payload,
      );

      return _processNativeResult(result, orderId, amount);
    } on MissingPluginException catch (e) {
      debugPrint('[NativeRazorpayCheckoutService] Native plugin missing: $e');
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.failed,
        orderId: orderId,
        errorCode: 'native_checkout_unavailable',
        errorMessage: 'Razorpay checkout is not available on this device.',
      );
      return CheckoutResult.failed;
    } on PlatformException catch (e) {
      debugPrint(
          '[NativeRazorpayCheckoutService] PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'CANCELLED' || e.code == 'PAYMENT_CANCELLED') {
        _lastResponse = CheckoutResponse(
          result: CheckoutResult.cancelled,
          orderId: orderId,
          errorCode: e.code,
          errorMessage: e.message ?? 'User cancelled checkout.',
        );
        return CheckoutResult.cancelled;
      }
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.failed,
        orderId: orderId,
        errorCode: e.code,
        errorMessage: e.message ?? 'Payment failed.',
      );
      return CheckoutResult.failed;
    } catch (e) {
      debugPrint(
          '[NativeRazorpayCheckoutService] Unexpected checkout error: $e');
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.failed,
        orderId: orderId,
        errorCode: 'checkout_error',
        errorMessage: 'Payment could not be started. Please try again.',
      );
      return CheckoutResult.failed;
    }
  }

  CheckoutResult _processNativeResult(
    Map<dynamic, dynamic>? result,
    String orderId,
    double amount,
  ) {
    if (result == null) {
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.failed,
        orderId: orderId,
        errorMessage: 'Empty response received from native payment sheet.',
      );
      return CheckoutResult.failed;
    }

    final status = result['status']?.toString().toLowerCase();

    if (status == 'success') {
      final paymentId = result['paymentId']?.toString() ??
          result['razorpay_payment_id']?.toString();
      if (paymentId == null || paymentId.isEmpty) {
        _lastResponse = CheckoutResponse(
          result: CheckoutResult.failed,
          orderId: orderId,
          errorCode: 'missing_payment_reference',
          errorMessage: 'The payment provider returned no payment reference.',
        );
        return CheckoutResult.failed;
      }
      final signature = result['signature']?.toString() ??
          result['razorpay_signature']?.toString();

      _lastResponse = CheckoutResponse(
        result: CheckoutResult.paid,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      );
      return CheckoutResult.paid;
    }

    if (status == 'cancelled') {
      _lastResponse = CheckoutResponse(
        result: CheckoutResult.cancelled,
        orderId: orderId,
        errorMessage: 'Payment dismissed by user.',
      );
      return CheckoutResult.cancelled;
    }

    _lastResponse = CheckoutResponse(
      result: CheckoutResult.failed,
      orderId: orderId,
      errorCode: result['errorCode']?.toString() ?? 'ERR_PAYMENT_FAILED',
      errorMessage: result['message']?.toString() ??
          result['errorDescription']?.toString() ??
          'Payment could not be completed.',
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
