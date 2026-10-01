import 'package:bookmyspace/features/analytics/domain/revenue_analytics.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:flutter_test/flutter_test.dart';

Booking _b(
  String id, {
  String venue = 'v1',
  BookingStatus status = BookingStatus.confirmed,
  double total = 1000,
  String method = 'upi',
  bool offline = false,
  DateTime? date,
  Map<String, dynamic> metadata = const {},
}) => Booking(
  id: id,
  bookingRef: 'BMS-$id',
  venueId: venue,
  slotId: 's1',
  bookDate: date ?? DateTime(2026, 9, 10),
  startTime: '10:00:00',
  endTime: '12:00:00',
  status: status,
  amount: total,
  taxAmount: 0,
  totalAmount: total,
  venueName: venue == 'v1' ? 'Sunrise Hall' : 'Lotus Banquet',
  paymentMethod: method,
  isOffline: offline,
  metadata: metadata,
);

void main() {
  final start = DateTime(2026, 9, 1);
  final end = DateTime(2026, 9, 30);

  test('classifies payment methods', () {
    expect(PaymentMethodKind.classify('UPI'), PaymentMethodKind.upi);
    expect(PaymentMethodKind.classify('phonepe'), PaymentMethodKind.upi);
    expect(PaymentMethodKind.classify('card'), PaymentMethodKind.card);
    expect(
      PaymentMethodKind.classify('netbanking'),
      PaymentMethodKind.netBanking,
    );
    expect(PaymentMethodKind.classify('wallet'), PaymentMethodKind.wallet);
    expect(PaymentMethodKind.classify('pay_at_venue'), PaymentMethodKind.cash);
    expect(
      PaymentMethodKind.classify('', offline: true),
      PaymentMethodKind.cash,
    );
    expect(PaymentMethodKind.classify(''), PaymentMethodKind.other);
  });

  test('splits revenue by method and online vs pay at venue', () {
    final report = BusinessReportCalculator.build(
      bookings: [
        _b('1', total: 2000, method: 'upi'),
        _b('2', total: 1000, method: 'card'),
        _b('3', total: 500, method: 'netbanking'),
        _b('4', total: 500, method: 'pay_at_venue'),
        _b('5', total: 1000, method: '', offline: true),
        // excluded: cancelled, request, out of range
        _b('6', status: BookingStatus.cancelled),
        _b('7', status: BookingStatus.awaitingOwnerApproval),
        _b('8', date: DateTime(2026, 10, 2)),
      ],
      start: start,
      end: end,
    );
    expect(report.bookingCount, 5);
    expect(report.revenue, 5000);
    expect(report.onlineCount, 3);
    expect(report.payAtVenueCount, 2);
    expect(report.onlinePercent, closeTo(60, 0.001));
    expect(report.payAtVenuePercent, closeTo(40, 0.001));
    expect(report.onlineRevenue, 3500);
    expect(report.payAtVenueRevenue, 1500);
    expect(report.methodSplit.map((s) => s.kind), [
      PaymentMethodKind.upi,
      PaymentMethodKind.card,
      PaymentMethodKind.netBanking,
      PaymentMethodKind.cash,
    ]);
    final upi = report.methodSplit.first;
    expect(upi.amount, 2000);
    expect(upi.count, 1);
    expect(upi.percent, closeTo(40, 0.001));
    expect(
      report.methodSplit.fold<double>(0, (s, e) => s + e.percent),
      closeTo(100, 0.001),
    );
  });

  test('sums advance tokens and guests', () {
    final report = BusinessReportCalculator.build(
      bookings: [
        _b('1', metadata: {'guests': 120, 'deposit': 5000}),
        _b('2', metadata: {'guests': '30', 'advance_amount': 1500.5}),
        _b('3'), // no guests recorded -> one party
      ],
      start: start,
      end: end,
    );
    expect(report.totalGuests, 151);
    expect(report.advanceTokensCollected, closeTo(6500.5, 0.001));
    expect(report.advanceTokenCount, 2);
  });

  test('venue filter and empty report', () {
    final bookings = [
      _b('1', venue: 'v1', total: 1000),
      _b('2', venue: 'v2', total: 3000, method: 'cash'),
    ];
    final v2 = BusinessReportCalculator.build(
      bookings: bookings,
      start: start,
      end: end,
      venueId: 'v2',
    );
    expect(v2.bookingCount, 1);
    expect(v2.revenue, 3000);
    expect(v2.payAtVenuePercent, 100);

    final none = BusinessReportCalculator.build(
      bookings: bookings,
      start: DateTime(2025),
      end: DateTime(2025, 2),
    );
    expect(none.isEmpty, isTrue);
    expect(none.onlinePercent, 0);
    expect(none.methodSplit, isEmpty);
  });
}
