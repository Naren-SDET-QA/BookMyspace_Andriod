import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bookmyspace/main.dart' as app;

/// E2E step 2/3: owner.dev signs in, opens /owner/bookings, locates the
/// booking ref passed in E2E_BOOKING_REF, verifies the tile, and approves
/// through the real UI (Accept & request payment -> approve_venue_booking).
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

  testWidgets('owner approves the booking via UI', (tester) async {
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
    router.go('/owner/bookings');
    await pumpFor(tester, 10);

    // Locate + verify the booking tile: ref, awaiting status, amount.
    final refFinder = find.textContaining(ref);
    expect(refFinder, findsOneWidget,
        reason: 'booking $ref must be listed for owner.dev');
    expect(find.text('awaiting_owner_approval'), findsAtLeastNWidgets(1));
    expect(find.textContaining('86,140'), findsAtLeastNWidgets(1),
        reason: 'tile should show the INR-formatted total');

    // Approve via the real action button.
    await tester
        .tap(find.widgetWithText(FilledButton, 'Accept & request payment'));
    await pumpFor(tester, 12);

    // Transition asserted on-screen: status chip pending, actions gone.
    expect(find.textContaining(ref), findsOneWidget,
        reason: 'booking stays listed after approval');
    expect(find.text('pending'), findsAtLeastNWidgets(1),
        reason: 'status chip must transition to pending');
    expect(find.text('awaiting_owner_approval'), findsNothing);
    expect(find.text('Accept & request payment'), findsNothing,
        reason: 'action buttons disappear once approved');
  });
}
