import '../../booking/domain/booking.dart';

/// Booking statuses that hold a slot (mirrors the `available_time_slots`
/// RPC: held, awaiting/pending owner approval, pending, confirmed,
/// completed).
const occupyingStatuses = {
  BookingStatus.held,
  BookingStatus.awaitingOwnerApproval,
  BookingStatus.pendingOwnerApproval,
  BookingStatus.pending,
  BookingStatus.confirmed,
  BookingStatus.completed,
};

/// A venue's sellable inventory: its active slots and blocked dates.
class VenueCapacity {
  const VenueCapacity({
    required this.venueId,
    required this.slots,
    this.blockedDates = const {},
  });

  final String venueId;
  final List<TimeSlot> slots;

  /// Local-midnight dates the venue is closed.
  final Set<DateTime> blockedDates;
}

/// Time-of-day window used by the demand heatmap.
class DemandWindowSpec {
  const DemandWindowSpec(this.name, this.startHour, this.endHour);
  final String name;
  final int startHour; // inclusive
  final int endHour; // exclusive

  String get range =>
      '${_two(startHour)}:00 - ${_two(endHour == 24 ? 0 : endHour)}:00';
  bool contains(int hour) => hour >= startHour && hour < endHour;
  static String _two(int h) => h.toString().padLeft(2, '0');
}

const demandWindows = [
  DemandWindowSpec('Late night', 0, 6),
  DemandWindowSpec('Morning', 6, 11),
  DemandWindowSpec('Afternoon', 11, 16),
  DemandWindowSpec('Evening', 16, 21),
  DemandWindowSpec('Night', 21, 24),
];

enum DemandBand { low, moderate, high }

class DemandWindow {
  const DemandWindow({
    required this.spec,
    required this.capacity,
    required this.occupied,
  });

  final DemandWindowSpec spec;

  /// Slot-days on sale in this window across the range.
  final int capacity;

  /// Slot-days in this window held by a booking.
  final int occupied;

  double get fillPercent => capacity == 0 ? 0 : occupied / capacity * 100;

  DemandBand get band => fillPercent >= 80
      ? DemandBand.high
      : fillPercent >= 40
      ? DemandBand.moderate
      : DemandBand.low;

  String get hint => switch (band) {
    DemandBand.low => 'Low demand: good window for an off-peak promotion',
    DemandBand.moderate => 'Moderate demand: standard pricing',
    DemandBand.high => 'High demand: prime window, consider more slots',
  };
}

class OptimizerRecommendation {
  const OptimizerRecommendation(this.title, this.detail);
  final String title;
  final String detail;
}

/// Venue Optimizer report for an owner over a date range. Every figure is
/// computed from the owner's own slots, blocked dates and bookings; nothing
/// is estimated or simulated.
class VenueOptimizerReport {
  const VenueOptimizerReport({
    required this.capacity,
    required this.occupied,
    required this.unsoldValue,
    required this.windows,
    required this.recommendations,
    required this.days,
  });

  final int capacity;
  final int occupied;

  /// Base price of the slots that went unbooked in the range.
  final double unsoldValue;
  final List<DemandWindow> windows;
  final List<OptimizerRecommendation> recommendations;
  final int days;

  bool get hasInventory => capacity > 0;
  double get occupancyPercent => capacity == 0 ? 0 : occupied / capacity * 100;

  static VenueOptimizerReport build({
    required List<VenueCapacity> venues,
    required List<Booking> bookings,
    required DateTime start,
    required DateTime end,
    String? venueId,
  }) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    final dates = <DateTime>[
      for (
        var d = first;
        !d.isAfter(last);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];

    // Occupying bookings grouped by venue and day.
    final byVenueDay = <String, List<Booking>>{};
    for (final b in bookings) {
      if (!occupyingStatuses.contains(b.status)) continue;
      final day = DateTime(b.bookDate.year, b.bookDate.month, b.bookDate.day);
      if (day.isBefore(first) || day.isAfter(last)) continue;
      byVenueDay.putIfAbsent('${b.venueId}|$day', () => []).add(b);
    }

    final cap = List<int>.filled(demandWindows.length, 0);
    final occ = List<int>.filled(demandWindows.length, 0);
    var capacity = 0;
    var occupied = 0;
    var unsold = 0.0;

    for (final venue in venues) {
      if (venueId != null && venue.venueId != venueId) continue;
      final slots = venue.slots.where((s) => s.isActive).toList();
      if (slots.isEmpty) continue;
      for (final day in dates) {
        if (venue.blockedDates.contains(day)) continue;
        final dayBookings = byVenueDay['${venue.venueId}|$day'] ?? const [];
        for (final slot in slots) {
          final span = _span(slot.startTime, slot.endTime);
          if (span == null) continue;
          final window = demandWindows.indexWhere(
            (w) => w.contains(span.$1 ~/ 60),
          );
          if (window < 0) continue;
          final taken = dayBookings.any((b) {
            if (b.slotId.isNotEmpty && b.slotId == slot.id) return true;
            final other = _span(b.startTime, b.endTime);
            return other != null && other.$1 < span.$2 && other.$2 > span.$1;
          });
          capacity++;
          cap[window]++;
          if (taken) {
            occupied++;
            occ[window]++;
          } else {
            unsold += slot.priceAmount;
          }
        }
      }
    }

    final windows = [
      for (var i = 0; i < demandWindows.length; i++)
        if (cap[i] > 0)
          DemandWindow(
            spec: demandWindows[i],
            capacity: cap[i],
            occupied: occ[i],
          ),
    ];

    return VenueOptimizerReport(
      capacity: capacity,
      occupied: occupied,
      unsoldValue: unsold,
      windows: windows,
      recommendations: occupied == 0 ? const [] : _recommend(windows),
      days: dates.length,
    );
  }

  static List<OptimizerRecommendation> _recommend(List<DemandWindow> windows) {
    final out = <OptimizerRecommendation>[];
    for (final w in windows) {
      final pct = w.fillPercent.round();
      switch (w.band) {
        case DemandBand.low:
          out.add(
            OptimizerRecommendation(
              'Fill ${w.spec.name.toLowerCase()} slots',
              '${w.spec.name} (${w.spec.range}) is $pct% booked. A coupon '
                  'or promotion for this window could fill '
                  '${w.capacity - w.occupied} open slots.',
            ),
          );
        case DemandBand.high:
          out.add(
            OptimizerRecommendation(
              'Expand ${w.spec.name.toLowerCase()} capacity',
              '${w.spec.name} (${w.spec.range}) is $pct% booked. Adding '
                  'slots in this window is likely to sell.',
            ),
          );
        case DemandBand.moderate:
          break;
      }
    }
    return out;
  }

  /// Minutes from midnight for a slot; an end before the start (for
  /// example 23:00-00:00 or 22:00-02:00) runs past midnight. A zero-length
  /// span is treated as unknown rather than as a 24-hour booking.
  static (int, int)? _span(String start, String end) {
    final s = _minutes(start);
    var e = _minutes(end);
    if (s == null || e == null || s == e) return null;
    if (e < s) e += 24 * 60;
    return (s, e);
  }

  static int? _minutes(String time) {
    final parts = time.split(':');
    if (parts.isEmpty) return null;
    final h = int.tryParse(parts[0].trim());
    final m = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    if (h == null || h < 0 || h > 24 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }
}

/// Read-only view of a `pricing_rules` row. Tolerates both the B10 schema
/// (rule_type / adjustment_percent) and the older multiplier-only schema.
class PricingRuleSummary {
  const PricingRuleSummary({
    required this.venueId,
    required this.description,
    required this.isAdjustment,
  });

  final String venueId;
  final String description;

  /// False for neutral placeholder rows (multiplier 1.00, no adjustment).
  final bool isAdjustment;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  factory PricingRuleSummary.fromJson(Map<String, dynamic> json) {
    final type = (json['rule_type'] as String?)?.toLowerCase();
    final pct = (json['adjustment_percent'] as num?)?.toDouble();
    final mult = (json['price_multiplier'] as num?)?.toDouble() ?? 1;
    final dow = (json['day_of_week'] as num?)?.toInt();
    final from = json['start_date'] as String?;
    final to = json['end_date'] as String?;
    final name =
        (json['label'] as String?)?.trim().isNotEmpty == true
        ? (json['label'] as String).trim()
        : (json['note'] as String?)?.trim() ?? '';

    String effect;
    bool adjusts;
    if ((type == 'discount' || type == 'surcharge') && pct != null) {
      adjusts = pct > 0;
      effect = type == 'discount'
          ? '${_fmt(pct)}% off'
          : '+${_fmt(pct)}% surcharge';
    } else {
      adjusts = (mult - 1).abs() > 0.0001;
      final change = (mult - 1) * 100;
      effect = !adjusts
          ? 'No change'
          : change > 0
          ? '+${_fmt(change)}% surcharge'
          : '${_fmt(-change)}% off';
    }
    final when = [
      if (dow != null && dow >= 0 && dow <= 6) _days[dow],
      if (from != null || to != null) '${from ?? '…'} to ${to ?? '…'}',
    ].join(', ');
    return PricingRuleSummary(
      venueId: json['venue_id'] as String? ?? '',
      isAdjustment: adjusts,
      description: [
        if (name.isNotEmpty) name,
        effect,
        if (when.isNotEmpty) when else 'every day',
      ].join(' · '),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
