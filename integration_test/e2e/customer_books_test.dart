import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bookmyspace/main.dart' as app;

/// E2E step 1/3: customer.dev signs in and books Party Hall DEV 10 through
/// the real UI (today, Afternoon slot, fallback Morning). Writes the new
/// booking ref to /tmp/e2e_booking_ref.txt for the owner step.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  const venueId = '51c4ea2c-7c9a-40c2-98a8-b9a50843ddf5';
  const email = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');

  Future<void> pumpFor(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> signIn(
      WidgetTester tester, String email, String password) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await pumpFor(tester, 1);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password (optional)'), password);
    await pumpFor(tester, 1);
    await tester.tap(find.byKey(const Key('otp-submit')));
    await pumpFor(tester, 8);
  }

  testWidgets('customer books Party Hall DEV 10 via UI', (tester) async {
    app.main();
    await pumpFor(tester, 8);

    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget,
        reason: 'router gate should land on /login');
    await signIn(tester, email, password);
    await pumpFor(tester, 3);

    final router =
        GoRouter.of(tester.state(find.byType(Navigator).first).context);
    // Venue details first: the booking route requires the Venue object as
    // `extra`, which only the details screen's Book CTA provides.
    router.go('/v1/venues/$venueId');
    await pumpFor(tester, 8);
    await tester.tap(find.textContaining('Book Now').first);
    await pumpFor(tester, 8);

    // Target tomorrow's date chip (Sat 19): booking for *today* risks the
    // slot already having started (IST afternoon), which could make the
    // request fail or instantly time out against the venue calendar.
    await tester.tap(find.text('19').first);
    await pumpFor(tester, 3);

    // Pick the Afternoon slot tile by label; fall back to Morning. Never a
    // blind first-InkWell tap: card FavoriteButtons are also InkWells and a
    // stray toggle writes to the favorites table (RLS) mid-test.
    final afternoon = find.widgetWithText(InkWell, 'Afternoon');
    final morning = find.widgetWithText(InkWell, 'Morning');
    if (afternoon.evaluate().isNotEmpty) {
      await tester.tap(afternoon.first);
    } else {
      expect(morning, findsOneWidget,
          reason: 'an available slot tile must be present');
      await tester.tap(morning.first);
    }
    await pumpFor(tester, 2);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm Booking'));
    await pumpFor(tester, 2);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm').last);
    await pumpFor(tester, 12);

    // Success screen shows the venue name, not the ref — read it from the
    // My Bookings row instead ('Ref: #BMS-XXXXXXXX').
    router.go('/bookings');
    await pumpFor(tester, 8);
    final refFinder = find.textContaining(RegExp(r'BMS-[0-9A-F]{8}'));
    expect(refFinder, findsAtLeastNWidgets(1),
        reason: 'new booking must appear in My Bookings');
    final rowText = tester.widget<Text>(refFinder.first).data!;
    final ref = RegExp(r'BMS-[0-9A-F]{8}').firstMatch(rowText)!.group(0)!;
    File('/tmp/e2e_booking_ref.txt').writeAsStringSync(ref);
    debugPrint('E2E_BOOKING_REF=' + ref);
  });
}
