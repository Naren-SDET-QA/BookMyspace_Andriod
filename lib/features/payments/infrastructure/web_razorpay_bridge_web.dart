import 'dart:convert';
import 'dart:js_interop';

@JS('bookMySpaceRazorpay')
external JSObject? get _bridge;

@JS('bookMySpaceRazorpay.isAvailable')
external JSBoolean? _jsIsAvailable();

@JS('bookMySpaceRazorpay.openCheckout')
external JSPromise<JSString>? _jsOpenCheckout(JSString optionsJson);

/// Browser bridge to `window.bookMySpaceRazorpay` (Checkout.js).
class WebRazorpayBridge {
  static bool get isAvailable {
    try {
      if (_bridge == null) return false;
      return _jsIsAvailable()?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> openCheckout(String optionsJson) async {
    final promise = _jsOpenCheckout(optionsJson.toJS);
    if (promise == null) {
      return const {
        'status': 'failed',
        'errorCode': 'web_checkout_unavailable',
        'message': 'Razorpay Checkout.js is not loaded.',
      };
    }
    final json = (await promise.toDart).toDart;
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {
      'status': 'failed',
      'errorCode': 'invalid_checkout_response',
      'message': 'Checkout returned an unexpected response.',
    };
  }
}
