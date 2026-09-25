import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bookmyspace/main.dart' as app;

/// E2E step 3/3: customer.dev signs in, opens /bookings, and verifies the
/// approved booking now exposes the real Pay affordance ('Pay securely').
/// The payment itself is NOT completed.
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

  testWidgets('customer sees payment available after approval', (tester) async {
    app.main();
    await pumpFor(tester, 8);

    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget,
        reason: 'router gate should land on /login');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
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

    expect(find.text(ref), findsOneWidget,
        reason: 'booking $ref must be listed for customer.dev');
    expect(find.widgetWithText(FilledButton, 'Pay securely'),
        findsAtLeastNWidgets(1),
        reason: 'approval must unlock the Pay affordance');
  });
}
