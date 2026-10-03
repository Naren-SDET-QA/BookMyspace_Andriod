import 'booking.dart';

/// Which days a crowd forecast covers.
enum DemandDayType {
  weekday('Weekdays (Mon-Fri)', 'weekday'),
  weekend('Weekends (Sat-Sun)', 'weekend');

  const DemandDayType(this.label, this.noun);
  final String label;
  final String noun;

  static DemandDayType of(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday
      ? DemandDayType.weekend
      : DemandDayType.weekday;
}

/// Crowd level of one hour, derived from real slot occupancy.
enum CrowdLevel {
  quiet('Quiet', 'Best time: plenty of open slots.'),
  moderate('Moderate', 'Moderate demand. Book a day or two ahead.'),
  peak('Peak Crowd', 'High demand slot. Book in advance to lock entry.');

  const CrowdLevel(this.label, this.advice);
  final String label;
  final String advice;

  static CrowdLevel of(double percent) => percent >= 75
      ? CrowdLevel.peak
      : percent >= 45
      ? CrowdLevel.moderate
      : CrowdLevel.quiet;
}

class HourDemand {
  const HourDemand({
    required this.hour,
    required this.taken,
    required this.total,
  });

  /// Hour of day (0-23) the slots start in.
  final int hour;

  /// Slots booked or held at this hour across the sampled days.
  final int taken;

  /// Bookable slots at this hour across the sampled days (blocked and past
  /// slots are excluded).
  final int total;

  double get percent => total == 0 ? 0 : taken / total * 100;
  CrowdLevel get level => CrowdLevel.of(percent);

  String get label {
    final period = hour >= 12 ? 'PM' : 'AM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve $period';
  }
}

/// Popular-times forecast for one venue, computed from the slot
/// availability of upcoming dates (booked + held vs bookable slots).
class SlotDemandForecast {
  const SlotDemandForecast({
    required this.hours,
    required this.dayType,
    required this.sampledDays,
  });

  final List<HourDemand> hours;
  final DemandDayType dayType;
  final int sampledDays;

  /// No bookings at all yet: a chart would be a flat line, so the UI shows
  /// an explanatory empty state instead.
  bool get hasSignal => hours.any((h) => h.taken > 0);

  HourDemand? get peak => hours.isEmpty
      ? null
      : hours.reduce((a, b) => b.percent > a.percent ? b : a);

  HourDemand? get best => hours.isEmpty
      ? null
      : hours.reduce((a, b) => b.percent < a.percent ? b : a);

  HourDemand? forHour(int hour) {
    for (final h in hours) {
      if (h.hour == hour) return h;
    }
    return null;
  }

  /// Builds the forecast from per-date slot availability
  /// (`available_time_slots` RPC rows).
  ///
  /// Only `available`, `booked` and `held` slots count as bookable capacity;
  /// `blocked`, `inactive` and any unknown unavailable reason are excluded.
  /// Slots on [now]'s date that already started are excluded too, since the
  /// RPC still reports them as `available`.
  static SlotDemandForecast build(
    Map<DateTime, List<SlotAvailability>> slotsByDate,
    DemandDayType dayType, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final taken = <int, int>{};
    final total = <int, int>{};
    var days = 0;
    slotsByDate.forEach((date, slots) {
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(today)) return;
      if (DemandDayType.of(day) != dayType) return;
      days++;
      for (final slot in slots) {
        final reason = slot.reason.trim().toLowerCase();
        final isTaken = reason == 'booked' || reason == 'held';
        if (!isTaken && !(slot.isAvailable && reason == 'available')) {
          continue;
        }
        final hour = hourOf(slot.startTime);
        if (hour == null) continue;
        if (day == today && !isTaken) {
          final minute = _minuteOf(slot.startTime);
          if (hour * 60 + minute <= clock.hour * 60 + clock.minute) continue;
        }
        total[hour] = (total[hour] ?? 0) + 1;
        if (isTaken) taken[hour] = (taken[hour] ?? 0) + 1;
      }
    });
    return SlotDemandForecast(
      dayType: dayType,
      sampledDays: days,
      hours: [
        for (final hour in operatingOrder(total.keys))
          HourDemand(hour: hour, taken: taken[hour] ?? 0, total: total[hour]!),
      ],
    );
  }

  /// Orders hours along the venue's operating day. Only a venue that runs
  /// past midnight (has early-morning hours before 6 AM as well as evening
  /// hours) is rotated to start right after its largest closed gap, so an
  /// 18:00-02:00 venue reads 6 PM ... 1 AM instead of 12 AM, 1 AM, 6 PM.
  static List<int> operatingOrder(Iterable<int> hours) {
    final sorted = hours.toSet().toList()..sort();
    if (sorted.length < 2) return sorted;
    final pastMidnight = sorted.first < 6 && sorted.last >= 12;
    if (!pastMidnight) return sorted;
    var start = 0;
    var widest = -1;
    for (var i = 0; i < sorted.length; i++) {
      final prev = sorted[(i - 1 + sorted.length) % sorted.length];
      final gap = (sorted[i] - prev + 24) % 24;
      if (gap > widest) {
        widest = gap;
        start = i;
      }
    }
    return [...sorted.sublist(start), ...sorted.sublist(0, start)];
  }

  static int _minuteOf(String time) {
    final parts = time.split(':');
    return parts.length < 2 ? 0 : int.tryParse(parts[1].trim()) ?? 0;
  }

  static int? hourOf(String startTime) {
    final hour = int.tryParse(startTime.split(':').first.trim());
    if (hour == null || hour < 0 || hour > 23) return null;
    return hour;
  }
}
