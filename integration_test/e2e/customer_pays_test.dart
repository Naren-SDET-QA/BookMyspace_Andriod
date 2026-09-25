import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bookmyspace/main.dart' as app;

/// E2E step 4/4: customer.dev signs in, opens the approved booking's checkout
/// from My Bookings ('Pay securely'), completes the REAL Razorpay test-mode
/// checkout in the browser, and waits for the server-side webhook
/// (razorpay-webhook) to move the booking pending -> confirmed.
///
/// Cross-origin: the Razorpay modal is an iframe the widget tree cannot
/// reach. This test publishes phase 'order' on `window.e2eRazorpayPhase`
/// right before tapping Pay Securely; a companion CDP driver
/// (/tmp/e2e_cdp_pay.mjs) waits for that flag, drives the test-mode payment
/// inside the Razorpay iframe, and reports on /tmp/e2e_cdp.log. No app code
/// is modified; the driver only interacts with the Razorpay checkout UI.
@JS('e2eRazorpayPhase')
external set _e2ePhase(JSString? value);

void setPhase(String p) => _e2ePhase = p.toJS;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  const email = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');
  const ref = String.fromEnvironment('E2E_BOOKING_REF');

  Future<void> pumpFor(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('customer pays via Razorpay checkout, booking -> confirmed',
      (tester) async {
    app.main();
    await pumpFor(tester, 8);

    // Fresh Chrome profile per drive run -> router gate lands on /login.
    final emailField = find.widgetWithText(TextFormField, 'Email');
    expect(emailField, findsOneWidget,
        reason: 'router gate should land on /login');
    await tester.enterText(emailField, email);
    await pumpFor(tester, 1);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password (optional)'), password);
    await pumpFor(tester, 1);
    await tester.tap(find.byKey(const Key('otp-submit')));
    await pumpFor(tester, 8);

    final router =
        GoRouter.of(tester.state(find.byType(Navigator).first).context);
    router.go('/bookings');
    await pumpFor(tester, 10);

    expect(find.textContaining(ref), findsAtLeastNWidgets(1),
        reason: 'approved booking $ref must be listed for customer.dev');
    expect(find.text('pending'), findsAtLeastNWidgets(1),
        reason: 'booking must be pending (owner-approved, awaiting payment)');
    final payRow = find.widgetWithText(FilledButton, 'Pay securely');
    expect(payRow, findsAtLeastNWidgets(1),
        reason: 'pay affordance must be present on the approved row');

    // ---- Checkout screen (real UI path) ----
    await tester.tap(payRow.first);
    await pumpFor(tester, 8);

    expect(find.textContaining('Secure Checkout'), findsOneWidget,
        reason: 'checkout screen must be open');
    expect(find.textContaining(ref), findsAtLeastNWidgets(1),
        reason: 'checkout summary must show the booking ref');
    final payBtn = find.widgetWithText(FilledButton, 'Pay Securely');
    expect(payBtn, findsOneWidget,
        reason: 'checkout bottom-bar pay button must render');

    // ---- Launch the real Razorpay Checkout.js modal ----
    // create-payment-order Edge Function runs first (~seconds), then the
    // cross-origin modal iframe appears; the CDP driver completes the
    // test-mode payment inside it.
    setPhase('order');
    await tester.tap(payBtn);

    // ---- Webhook confirmation: same observation the app performs ----
    // PaymentNotifier polls 10 x 2s after client success; the webhook may
    // lag, so poll generously via the UI and tap the pending card's
    // 'Refresh status' (refreshPaymentStatus) when it appears.
    final confirmedTitle = find.text('Booking confirmed');
    var confirmed = false;
    for (var i = 0; i < 60 && !confirmed; i++) {
      await pumpFor(tester, 2);
      if (confirmedTitle.evaluate().isNotEmpty) {
        confirmed = true;
        break;
      }
      final refresh = find.widgetWithText(OutlinedButton, 'Refresh status');
      if (i % 4 == 3 && refresh.evaluate().isNotEmpty) {
        await tester.tap(refresh.first);
      }
      if (find
          .text('Payment was cancelled. Your slot hold is still reserved.')
          .evaluate()
          .isNotEmpty) {
        fail('Razorpay modal was dismissed without completing payment');
      }
      if (i == 30) debugPrint('E2E_PAY_STILL_WAITING iteration=$i');
    }

    expect(confirmed, isTrue,
        reason:
            'razorpay-webhook must confirm booking $ref (pending -> confirmed) '
            'within the poll window');
    expect(find.textContaining(ref), findsAtLeastNWidgets(1),
        reason: 'success screen must show the confirmed booking');
    debugPrint('E2E_PAYMENT_CONFIRMED=$ref');
  });
}
