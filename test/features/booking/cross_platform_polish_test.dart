import 'package:bookmyspace/core/widgets/shimmer_loading.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/widgets/booking_progress_tracker.dart';
import 'package:bookmyspace/features/invoices/domain/invoice_design.dart';
import 'package:bookmyspace/features/qr_checkin/domain/check_in_verdict.dart';
import 'package:bookmyspace/features/qr_checkin/domain/qr_check_in.dart';
import 'package:bookmyspace/features/qr_checkin/presentation/widgets/pass_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Booking _booking(BookingStatus status) => Booking(
  id: 'b1',
  bookingRef: 'BMS-1',
  venueId: 'v1',
  slotId: 's1',
  bookDate: DateTime(2026, 10, 2),
  startTime: '10:00:00',
  endTime: '13:00:00',
  status: status,
  amount: 1000,
  taxAmount: 180,
  totalAmount: 1180,
  venueName: 'Royal Palace Hall',
  venueCity: 'Hyderabad',
  slotLabel: 'Evening',
);

void main() {
  test('invoice designs fall back to Modern Teal', () {
    expect(InvoiceDesign.parse(null), InvoiceDesign.modernTeal);
    expect(InvoiceDesign.parse('classic_navy'), InvoiceDesign.classicNavy);
    expect(InvoiceDesign.parse('minimal_mono').label, 'Minimalist Monochrome');
    expect(
      InvoiceDesign.parse('corporate_slate'),
      InvoiceDesign.corporateSlate,
    );
    expect(InvoiceDesign.parse('not-a-design'), InvoiceDesign.modernTeal);
  });

  test('check-in labels follow the server message', () {
    expect(
      classifyCheckIn(
        const CheckInResult(success: true, message: 'Check-in verified'),
      ),
      CheckInVerdict.valid,
    );
    expect(
      classifyCheckIn(
        const CheckInResult(success: false, message: 'Already checked in'),
      ),
      CheckInVerdict.alreadyCheckedIn,
    );
    expect(
      classifyCheckIn(
        const CheckInResult(success: false, message: 'Pass expired'),
      ),
      CheckInVerdict.expired,
    );
    expect(
      classifyCheckIn(
        const CheckInResult(success: false, message: 'Unknown code'),
      ),
      CheckInVerdict.invalid,
    );
  });

  test('host review progress follows the server status', () {
    expect(
      BookingReviewProgress.of(BookingStatus.awaitingOwnerApproval).activeIndex,
      1,
    );
    expect(BookingReviewProgress.of(BookingStatus.pending).activeIndex, 2);
    expect(BookingReviewProgress.of(BookingStatus.confirmed).activeIndex, 3);
    expect(
      BookingReviewProgress.of(BookingStatus.ownerRejected).failed,
      isTrue,
    );
  });

  testWidgets('loading placeholders and the review tracker render', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                VenueCardSkeleton(),
                CategoryCarouselSkeleton(count: 3),
                BookingSummarySkeleton(),
                InvoicePreviewSkeleton(),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ShimmerBox), findsWidgets);
    expect(find.byKey(const Key('category-carousel-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('booking-summary-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('invoice-preview-skeleton')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingProgressTracker(
            status: BookingStatus.awaitingOwnerApproval,
          ),
        ),
      ),
    );
    expect(find.text('Host reviewing'), findsOneWidget);
    expect(find.text('Entry pass'), findsOneWidget);
    expect(find.text('Host declined'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingProgressTracker(status: BookingStatus.ownerRejected),
        ),
      ),
    );
    expect(find.text('Host declined'), findsOneWidget);
  });

  testWidgets('a confirmed pass offers calendar, WhatsApp, and download', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassActions(booking: _booking(BookingStatus.confirmed)),
        ),
      ),
    );
    expect(find.byKey(const Key('pass-action-calendar')), findsOneWidget);
    expect(find.byKey(const Key('pass-action-whatsapp')), findsOneWidget);
    expect(find.byKey(const Key('pass-action-download')), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const Key('pass-action-calendar')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.style?.minimumSize?.resolve({}), const Size(48, 48));
  });
}
