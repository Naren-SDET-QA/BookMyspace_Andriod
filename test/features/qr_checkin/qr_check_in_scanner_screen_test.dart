import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/qr_checkin/presentation/screens/qr_check_in_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QR scanner can build with scan animation and tab controller',
      (tester) async {
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.text('My Entry Pass QR'), findsOneWidget);

    await tester.tap(find.text('My Entry Pass QR'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No Active Confirmed Bookings'), findsOneWidget);
  });
}
