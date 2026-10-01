/// VM / mobile stub. Web checkout JS is not available here.
class WebRazorpayBridge {
  static bool get isAvailable => false;

  static Future<Map<String, dynamic>> openCheckout(String optionsJson) async {
    return const {
      'status': 'failed',
      'errorCode': 'web_checkout_unavailable',
      'message': 'Razorpay Checkout.js is only available in the browser.',
    };
  }
}
