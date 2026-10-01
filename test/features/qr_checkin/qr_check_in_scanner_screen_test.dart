import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/qr_checkin/presentation/screens/qr_check_in_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myBookingsProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(
        home: QrCheckInScannerScreen(),
      ),
    ),
  );
  // The scanner starts its camera from a post-frame callback.
  await tester.pump();
  // The platform channel that starts the camera is never answered in this host:
  // `MobileScannerController.start()` neither completes nor throws, so the
  // scanner's own start deadline is what produces the fallback. Pump past it.
  await tester.pump(const Duration(seconds: 7));
  await tester.pump();
}

void main() {
  testWidgets('QR scanner can build with tab controller', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.text('My Entry Pass QR'), findsOneWidget);

    await tester.tap(find.text('My Entry Pass QR'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No Active Confirmed Bookings'), findsOneWidget);
  });

  testWidgets('a host without a camera explains itself and keeps manual entry',
      (tester) async {
    await _pumpScreen(tester);

    // No camera plugin is registered in the test host. The screen must say so
    // rather than presenting a dark rectangle as a working viewfinder, and it
    // must do that without leaking an unhandled asynchronous error — which is
    // exactly what mobile_scanner's unguarded autoStart would produce.
    expect(tester.takeException(), isNull);
    // Whichever way the camera failed, the user is pointed at manual entry.
    expect(
      find.textContaining('Enter the booking reference below'),
      findsOneWidget,
    );

    // Manual reference entry is the documented fallback.
    expect(find.byKey(const Key('manual_qr_input_field')), findsOneWidget);
    expect(find.byKey(const Key('submit_manual_qr_btn')), findsOneWidget);
  });

  testWidgets('manual entry still submits when the camera is unavailable',
      (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('manual_qr_input_field')),
      'BMS-883921',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('submit_manual_qr_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The repository cannot reach a server here, so the outcome is a failure
    // dialog. What matters is that the path runs and reports, rather than
    // throwing or silently doing nothing.
    expect(tester.takeException(), isNull);
    expect(find.text('Check-In Issue'), findsOneWidget);
  });
}
