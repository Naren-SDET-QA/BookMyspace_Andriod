import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/booking.dart';

/// Phase of a booking relative to "now" (reference BookingCountdownTimer).
enum BookingCountdownPhase {
  /// More than 24 hours before start.
  upcoming,

  /// Within 24 hours of start.
  imminent,

  /// Within 1 hour of start.
  urgent,

  /// Between start and end (or start + 1h when there is no end time).
  inProgress,
}

/// Snapshot of a booking countdown at a given instant.
class BookingCountdownInfo {
  const BookingCountdownInfo({
    required this.phase,
    required this.remaining,
    required this.start,
    required this.end,
  });

  final BookingCountdownPhase phase;

  /// Time until start, or until end while [BookingCountdownPhase.inProgress].
  final Duration remaining;
  final DateTime start;
  final DateTime end;

  /// "Xd hh:mm:ss" (days omitted when zero).
  String get formatted => BookingCountdown.format(remaining);
}

/// Pure countdown rules; no timers.
abstract final class BookingCountdown {
  static const _defaultDuration = Duration(hours: 1);

  /// Start instant of [booking] in local time, or null when unparsable.
  static DateTime? startOf(Booking booking) =>
      _combine(booking.bookDate, booking.startTime);

  /// End instant: the end time on the same day (next day when it wraps past
  /// midnight), or start + 1h when there is no usable end time.
  static DateTime? endOf(Booking booking) {
    final start = startOf(booking);
    if (start == null) return null;
    var end = _combine(booking.bookDate, booking.endTime);
    if (end == null) return start.add(_defaultDuration);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return end;
  }

  /// Countdown info, or null when the countdown must be hidden (not a
  /// confirmed booking, cancelled, or already finished).
  static BookingCountdownInfo? compute(Booking booking, DateTime now) {
    if (booking.status != BookingStatus.confirmed) return null;
    final start = startOf(booking);
    final end = endOf(booking);
    if (start == null || end == null) return null;
    if (now.isBefore(start)) {
      final diff = start.difference(now);
      final phase = diff <= const Duration(hours: 1)
          ? BookingCountdownPhase.urgent
          : diff <= const Duration(hours: 24)
          ? BookingCountdownPhase.imminent
          : BookingCountdownPhase.upcoming;
      return BookingCountdownInfo(
        phase: phase,
        remaining: diff,
        start: start,
        end: end,
      );
    }
    if (now.isBefore(end)) {
      return BookingCountdownInfo(
        phase: BookingCountdownPhase.inProgress,
        remaining: end.difference(now),
        start: start,
        end: end,
      );
    }
    return null;
  }

  static String format(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final days = d.inDays;
    String two(int v) => v.toString().padLeft(2, '0');
    final hms =
        '${two(d.inHours % 24)}:${two(d.inMinutes % 60)}:'
        '${two(d.inSeconds % 60)}';
    return days > 0 ? '${days}d $hms' : hms;
  }

  static DateTime? _combine(DateTime day, String time) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(time.trim());
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final s = int.tryParse(match.group(3) ?? '') ?? 0;
    if (h > 24 || m > 59 || s > 59) return null;
    return DateTime(day.year, day.month, day.day, h, m, s);
  }
}

/// Live "starts in Xd hh:mm:ss" banner for an upcoming confirmed booking.
///
/// Renders nothing for past, cancelled or unconfirmed bookings. Ticks once a
/// second and cancels its timer on dispose or once the booking has ended.
class BookingStartCountdown extends StatefulWidget {
  const BookingStartCountdown({super.key, required this.booking, this.now});

  final Booking booking;

  /// Injectable clock for tests.
  final DateTime Function()? now;

  @override
  State<BookingStartCountdown> createState() => _BookingStartCountdownState();
}

class _BookingStartCountdownState extends State<BookingStartCountdown> {
  Timer? _timer;
  BookingCountdownInfo? _info;

  DateTime _clock() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _refresh(schedule: true);
  }

  @override
  void didUpdateWidget(covariant BookingStartCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking != widget.booking) _refresh(schedule: true);
  }

  void _refresh({bool schedule = false}) {
    _info = BookingCountdown.compute(widget.booking, _clock());
    if (_info == null) {
      _timer?.cancel();
      _timer = null;
    } else if (schedule && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(_refresh);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (label, icon, background, foreground) = switch (info.phase) {
      BookingCountdownPhase.inProgress => (
        'In progress · ends in',
        Icons.play_circle_outline_rounded,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      BookingCountdownPhase.urgent => (
        'Starting soon',
        Icons.alarm_rounded,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      BookingCountdownPhase.imminent => (
        'Starts in',
        Icons.hourglass_top_rounded,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      BookingCountdownPhase.upcoming => (
        'Starts in',
        Icons.event_available_rounded,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };
    return Semantics(
      label: '$label ${info.formatted}',
      child: Container(
        key: const Key('booking_start_countdown'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              info.formatted,
              key: const Key('booking_start_countdown_value'),
              style: textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
