import '../domain/checkout_service.dart';
import 'native_razorpay_checkout_service.dart';

/// Android / iOS / VM factory: native MethodChannel checkout.
CheckoutService createCheckoutService() => NativeRazorpayCheckoutService();
