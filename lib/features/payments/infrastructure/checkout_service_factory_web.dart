import '../domain/checkout_service.dart';
import 'web_razorpay_checkout_service.dart';

/// Browser factory: Razorpay Checkout.js, never a native plugin.
CheckoutService createCheckoutService() => WebRazorpayCheckoutService();
