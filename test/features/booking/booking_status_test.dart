import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown server status stays neutral instead of becoming pending', () {
    expect(BookingStatus.fromDb('future_status'), BookingStatus.unknown);
    expect(BookingStatus.unknown.dbValue, 'unknown');
  });

  test('approval request is cancellable but never payable', () {
    final booking = Booking(
      id: 'request-1',
      bookingRef: 'BMS-REQUEST-1',
      venueId: 'venue-1',
      slotId: 'slot-1',
      bookDate: DateTime(2026, 9, 12),
      startTime: '09:00:00',
      endTime: '10:00:00',
      status: BookingStatus.awaitingOwnerApproval,
      amount: 100,
      taxAmount: 18,
      totalAmount: 118,
      approvalRequired: true,
    );

    expect(booking.canCancel, isTrue);
    expect(booking.canPay, isFalse);
    expect(booking.canRefund, isFalse);
  });

  test('approved pending booking is payable', () {
    final booking = Booking(
      id: 'pending-1',
      bookingRef: 'BMS-PENDING-1',
      venueId: 'venue-1',
      slotId: 'slot-1',
      bookDate: DateTime(2026, 9, 12),
      startTime: '09:00:00',
      endTime: '10:00:00',
      status: BookingStatus.pending,
      amount: 100,
      taxAmount: 18,
      totalAmount: 118,
      approvalRequired: true,
      approvedAt: DateTime(2026, 9, 12, 9),
    );

    expect(booking.canPay, isTrue);
  });

  test('rejected and expired requests never look confirmed or payable', () {
    for (final status in [
      BookingStatus.ownerRejected,
      BookingStatus.approvalExpired,
    ]) {
      final booking = Booking(
        id: 'request-$status',
        bookingRef: 'BMS-REQUEST',
        venueId: 'venue-1',
        slotId: 'slot-1',
        bookDate: DateTime(2026, 9, 12),
        startTime: '09:00:00',
        endTime: '10:00:00',
        status: status,
        amount: 100,
        taxAmount: 18,
        totalAmount: 118,
      );

      expect(booking.isActive, isFalse);
      expect(booking.canPay, isFalse);
      expect(booking.canRefund, isFalse);
    }
  });
}
