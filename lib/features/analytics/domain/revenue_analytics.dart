import '../../booking/domain/booking.dart';

class AnalyticsBookingRecord {
  const AnalyticsBookingRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.paymentCaptured,
    required this.category,
    required this.venue,
    this.refundAmount = 0,
    this.cancelled = false,
  });

  final String id;
  final DateTime date;
  final double amount;
  final bool paymentCaptured;
  final String category;
  final String venue;
  final double refundAmount;
  final bool cancelled;
}

class AnalyticsPoint {
  const AnalyticsPoint(this.label, this.value, this.count);
  final String label;
  final double value;
  final int count;
}

class AnalyticsBreakdown {
  const AnalyticsBreakdown(this.label, this.value, this.count);
  final String label;
  final double value;
  final int count;
}

class RevenueAnalytics {
  const RevenueAnalytics({
    required this.totalRevenue,
    required this.successfulBookings,
    required this.cancelledBookings,
    required this.refundAmount,
    required this.netRevenue,
    required this.averageBookingValue,
    required this.dailyRevenue,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.bookingTrend,
    required this.categoryRevenue,
    required this.venueRevenue,
  });

  factory RevenueAnalytics.empty() => const RevenueAnalytics(
    totalRevenue: 0,
    successfulBookings: 0,
    cancelledBookings: 0,
    refundAmount: 0,
    netRevenue: 0,
    averageBookingValue: 0,
    dailyRevenue: [],
    weeklyRevenue: [],
    monthlyRevenue: [],
    bookingTrend: [],
    categoryRevenue: [],
    venueRevenue: [],
  );

  final double totalRevenue;
  final int successfulBookings;
  final int cancelledBookings;
  final double refundAmount;
  final double netRevenue;
  final double averageBookingValue;
  final List<AnalyticsPoint> dailyRevenue;
  final List<AnalyticsPoint> weeklyRevenue;
  final List<AnalyticsPoint> monthlyRevenue;
  final List<AnalyticsPoint> bookingTrend;
  final List<AnalyticsBreakdown> categoryRevenue;
  final List<AnalyticsBreakdown> venueRevenue;

  bool get isEmpty => successfulBookings == 0 && cancelledBookings == 0;

  factory RevenueAnalytics.fromJson(Map<String, dynamic> json) {
    List<AnalyticsPoint> points(String key) =>
        ((json[key] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => AnalyticsPoint(
                '${row['label'] ?? ''}',
                (row['value'] as num?)?.toDouble() ?? 0,
                (row['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(growable: false);
    List<AnalyticsBreakdown> breakdown(String key) =>
        ((json[key] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => AnalyticsBreakdown(
                '${row['label'] ?? ''}',
                (row['value'] as num?)?.toDouble() ?? 0,
                (row['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(growable: false);
    return RevenueAnalytics(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      successfulBookings: (json['successful_bookings'] as num?)?.toInt() ?? 0,
      cancelledBookings: (json['cancelled_bookings'] as num?)?.toInt() ?? 0,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      netRevenue: (json['net_revenue'] as num?)?.toDouble() ?? 0,
      averageBookingValue:
          (json['average_booking_value'] as num?)?.toDouble() ?? 0,
      dailyRevenue: points('daily_revenue'),
      weeklyRevenue: points('weekly_revenue'),
      monthlyRevenue: points('monthly_revenue'),
      bookingTrend: points('booking_trend'),
      categoryRevenue: breakdown('category_revenue'),
      venueRevenue: breakdown('venue_revenue'),
    );
  }
}

class RevenueAnalyticsCalculator {
  static RevenueAnalytics calculate(
    List<AnalyticsBookingRecord> records,
    DateTime start,
    DateTime end,
  ) {
    final selected = records.where((record) {
      final day = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
          !day.isAfter(DateTime(end.year, end.month, end.day));
    });
    final successful = selected
        .where((record) => record.paymentCaptured && !record.cancelled)
        .toList();
    final refund = successful.fold<double>(
      0,
      (sum, row) => sum + row.refundAmount,
    );
    List<AnalyticsPoint> points(String Function(AnalyticsBookingRecord) key) {
      final grouped = <String, List<AnalyticsBookingRecord>>{};
      for (final row in successful) {
        grouped.putIfAbsent(key(row), () => []).add(row);
      }
      return grouped.entries
          .map(
            (entry) => AnalyticsPoint(
              entry.key,
              entry.value.fold(0, (sum, row) => sum + row.amount),
              entry.value.length,
            ),
          )
          .toList(growable: false);
    }

    final daily = points((row) => _day(row.date));
    final weekly = points((row) => _week(row.date));
    final monthly = points(
      (row) => '${row.date.year}-${row.date.month.toString().padLeft(2, '0')}',
    );
    List<AnalyticsBreakdown> breakdown(
      String Function(AnalyticsBookingRecord) key,
    ) {
      final grouped = <String, List<AnalyticsBookingRecord>>{};
      for (final row in successful)
        grouped.putIfAbsent(key(row), () => []).add(row);
      return grouped.entries
          .map(
            (entry) => AnalyticsBreakdown(
              entry.key,
              entry.value.fold(0, (sum, row) => sum + row.amount),
              entry.value.length,
            ),
          )
          .toList(growable: false);
    }

    final total = successful.fold<double>(0, (sum, row) => sum + row.amount);
    return RevenueAnalytics(
      totalRevenue: total,
      successfulBookings: successful.length,
      cancelledBookings: selected.where((row) => row.cancelled).length,
      refundAmount: refund,
      netRevenue: total - refund,
      averageBookingValue: successful.isEmpty ? 0 : total / successful.length,
      dailyRevenue: daily,
      weeklyRevenue: weekly,
      monthlyRevenue: monthly,
      bookingTrend: daily,
      categoryRevenue: breakdown((row) => row.category),
      venueRevenue: breakdown((row) => row.venue),
    );
  }

  static String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String _week(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return _day(monday);
  }
}

// ---------------------------------------------------------------------------
// Business report (payment-method split, online vs pay-at-venue, advance
// tokens and guests), computed client-side from the owner's booking rows.
// Ported from the reference app's BusinessReportEngine.
// ---------------------------------------------------------------------------

enum PaymentMethodKind {
  upi('UPI'),
  card('Card'),
  netBanking('Net banking'),
  wallet('Wallet'),
  cash('Cash / pay at venue'),
  other('Other / unknown');

  const PaymentMethodKind(this.label);
  final String label;

  bool get isPayAtVenue => this == PaymentMethodKind.cash;

  /// Classifies a free-text `payments.method` value (the column has no
  /// enum). Offline walk-in bookings count as cash.
  static PaymentMethodKind classify(String method, {bool offline = false}) {
    final m = method.trim().toLowerCase();
    if (offline ||
        m.contains('venue') ||
        m.contains('cash') ||
        m.contains('offline')) {
      return PaymentMethodKind.cash;
    }
    if (m.contains('upi') ||
        m.contains('gpay') ||
        m.contains('phonepe') ||
        m.contains('paytm') ||
        m.contains('bhim')) {
      return PaymentMethodKind.upi;
    }
    if (m.contains('card') ||
        m.contains('visa') ||
        m.contains('mastercard') ||
        m.contains('rupay') ||
        m.contains('debit') ||
        m.contains('credit')) {
      return PaymentMethodKind.card;
    }
    if (m.contains('netbanking') ||
        m.contains('net_banking') ||
        m.contains('net banking') ||
        m == 'nb' ||
        m.contains('bank')) {
      return PaymentMethodKind.netBanking;
    }
    if (m.contains('wallet')) return PaymentMethodKind.wallet;
    return PaymentMethodKind.other;
  }
}

class PaymentMethodSplit {
  const PaymentMethodSplit({
    required this.kind,
    required this.amount,
    required this.count,
    required this.percent,
  });

  final PaymentMethodKind kind;
  final double amount;
  final int count;

  /// Share of report revenue, 0-100.
  final double percent;
}

class BusinessReport {
  const BusinessReport({
    required this.bookingCount,
    required this.revenue,
    required this.methodSplit,
    required this.onlineCount,
    required this.payAtVenueCount,
    required this.onlineRevenue,
    required this.payAtVenueRevenue,
    required this.advanceTokensCollected,
    required this.advanceTokenCount,
    required this.totalGuests,
  });

  static const empty = BusinessReport(
    bookingCount: 0,
    revenue: 0,
    methodSplit: [],
    onlineCount: 0,
    payAtVenueCount: 0,
    onlineRevenue: 0,
    payAtVenueRevenue: 0,
    advanceTokensCollected: 0,
    advanceTokenCount: 0,
    totalGuests: 0,
  );

  final int bookingCount;
  final double revenue;

  /// One entry per [PaymentMethodKind] with at least one booking, in enum
  /// order.
  final List<PaymentMethodSplit> methodSplit;
  final int onlineCount;
  final int payAtVenueCount;
  final double onlineRevenue;
  final double payAtVenueRevenue;
  final double advanceTokensCollected;
  final int advanceTokenCount;
  final int totalGuests;

  bool get isEmpty => bookingCount == 0;

  double get onlinePercent =>
      bookingCount == 0 ? 0 : onlineCount / bookingCount * 100;
  double get payAtVenuePercent =>
      bookingCount == 0 ? 0 : payAtVenueCount / bookingCount * 100;
}

class BusinessReportCalculator {
  /// Statuses whose value is committed (paid, or confirmed to be paid at
  /// the venue). Requests, holds and cancelled/rejected rows are excluded.
  static const reportStatuses = {
    BookingStatus.confirmed,
    BookingStatus.completed,
    BookingStatus.noShow,
    BookingStatus.pendingOwnerApproval,
  };

  /// Metadata keys holding an advance / token / deposit amount.
  static const advanceKeys = [
    'advance_amount',
    'advance_paid',
    'token_amount',
    'deposit',
  ];

  static BusinessReport build({
    required List<Booking> bookings,
    required DateTime start,
    required DateTime end,
    String? venueId,
  }) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day);
    final rows = bookings.where((b) {
      if (venueId != null && b.venueId != venueId) return false;
      if (!reportStatuses.contains(b.status)) return false;
      final day = DateTime(b.bookDate.year, b.bookDate.month, b.bookDate.day);
      return !day.isBefore(from) && !day.isAfter(to);
    }).toList();
    if (rows.isEmpty) return BusinessReport.empty;

    final amounts = <PaymentMethodKind, double>{};
    final counts = <PaymentMethodKind, int>{};
    var revenue = 0.0;
    var advance = 0.0;
    var advanceCount = 0;
    var guests = 0;
    for (final b in rows) {
      final kind = PaymentMethodKind.classify(
        b.paymentMethod,
        offline: b.isOffline,
      );
      revenue += b.totalAmount;
      amounts[kind] = (amounts[kind] ?? 0) + b.totalAmount;
      counts[kind] = (counts[kind] ?? 0) + 1;
      final token = _advanceOf(b.metadata);
      if (token > 0) {
        advance += token;
        advanceCount++;
      }
      guests += guestCountOf(b.metadata);
    }
    final split = [
      for (final kind in PaymentMethodKind.values)
        if ((counts[kind] ?? 0) > 0)
          PaymentMethodSplit(
            kind: kind,
            amount: amounts[kind]!,
            count: counts[kind]!,
            percent: revenue <= 0 ? 0 : amounts[kind]! / revenue * 100,
          ),
    ];
    final venueCount = counts[PaymentMethodKind.cash] ?? 0;
    final venueRevenue = amounts[PaymentMethodKind.cash] ?? 0;
    return BusinessReport(
      bookingCount: rows.length,
      revenue: revenue,
      methodSplit: split,
      onlineCount: rows.length - venueCount,
      payAtVenueCount: venueCount,
      onlineRevenue: revenue - venueRevenue,
      payAtVenueRevenue: venueRevenue,
      advanceTokensCollected: advance,
      advanceTokenCount: advanceCount,
      totalGuests: guests,
    );
  }

  /// Guests recorded on the booking (`metadata.guests`), else 1 party.
  static int guestCountOf(Map<String, dynamic> metadata) {
    for (final key in const ['guests', 'guest_count', 'occupants']) {
      final raw = metadata[key];
      final value = raw is num
          ? raw.toInt()
          : raw is String
          ? int.tryParse(raw.trim())
          : null;
      if (value != null && value > 0) return value;
    }
    return 1;
  }

  static double _advanceOf(Map<String, dynamic> metadata) {
    for (final key in advanceKeys) {
      final raw = metadata[key];
      final value = raw is num
          ? raw.toDouble()
          : raw is String
          ? double.tryParse(raw.trim())
          : null;
      if (value != null && value > 0) return value;
    }
    return 0;
  }
}
