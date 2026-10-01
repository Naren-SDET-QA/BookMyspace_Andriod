import '../../booking/domain/booking.dart';

/// A calendar event derived from a [Booking], suitable for ICS export.
///
/// This is a pure data model — it holds no platform dependencies and can be
/// tested on any host without a device.
class CalendarEvent {
  const CalendarEvent({
    required this.uid,
    required this.title,
    required this.description,
    required this.location,
    required this.start,
    required this.end,
    required this.organizer,
  });

  /// Stable unique identifier for the VEVENT. Uses the booking id so
  /// re-importing the same .ics updates the event instead of duplicating it.
  final String uid;

  /// Human-readable summary line (SUMMARY property).
  final String title;

  /// Multi-line description (DESCRIPTION property).
  final String description;

  /// Venue address or city (LOCATION property).
  final String location;

  /// Start of the booking slot (DTSTART).
  final DateTime start;

  /// End of the booking slot (DTEND).
  final DateTime end;

  /// Email of the booking owner (ORGANIZER property).
  final String organizer;

  /// Factory that builds a [CalendarEvent] from a [Booking].
  ///
  /// Returns null when the booking has no valid time range (zero start/end)
  /// or no booking id — those bookings cannot produce a meaningful calendar
  /// entry.
  static CalendarEvent? fromBooking(Booking booking) {
    if (booking.id.isEmpty) return null;
    if (booking.startTime.isEmpty || booking.endTime.isEmpty) return null;

    final start = _composeDateTime(booking.bookDate, booking.startTime);
    final end = _composeDateTime(booking.bookDate, booking.endTime);
    if (start == null || end == null) return null;
    if (!end.isAfter(start)) return null;

    final venueName =
        booking.venueName.isNotEmpty ? booking.venueName : 'Venue Booking';
    final title = '$venueName — ${booking.slotLabel.isNotEmpty ? booking.slotLabel : 'Booking'}';

    final descParts = <String>[
      'Booking Ref: ${booking.bookingRef.isNotEmpty ? booking.bookingRef : booking.id}',
      'Status: ${booking.status.name}',
      if (booking.slotLabel.isNotEmpty) 'Slot: ${booking.slotLabel}',
      'Amount: ${booking.totalAmount}',
    ];

    return CalendarEvent(
      uid: '${booking.id}@bookmyspace.app',
      title: title,
      description: descParts.join('\n'),
      location: booking.venueCity.isNotEmpty
          ? booking.venueCity
          : 'See booking details',
      start: start,
      end: end,
      organizer: 'noreply@bookmyspace.app',
    );
  }

  /// Combines a date ([bookDate]) with a time string ("HH:mm:ss" or "HH:mm")
  /// into a single [DateTime] in UTC, so the ICS export is timezone-safe
  /// regardless of the user's device timezone.
  ///
  /// The booking's `bookDate` is a date-only [DateTime] (midnight local),
  /// and `startTime`/`endTime` are wall-clock strings stored on the server.
  /// We interpret them as Asia/Kolkata (IST, UTC+5:30) because the app's
  /// server schema and all venues are India-based, then convert to UTC for
  /// the ICS file. This avoids the `VTIMEZONE` complexity and guarantees the
  /// event lands at the correct wall-clock time in any calendar app.
  ///
  /// **Implementation detail**: `DateTime.utc(...)` is used so the resulting
  /// value is already in UTC and `_formatUtc` does not re-convert. Otherwise
  /// the test host's timezone would be applied twice (once in `DateTime(...)`
  /// which creates a local time, and once in `toUtc()` inside `_formatUtc`).
  static DateTime? _composeDateTime(DateTime date, String timeStr) {
    // Parse "HH:mm:ss" or "HH:mm"
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    // Build the wall-clock DateTime in IST (UTC+5:30) and convert to UTC.
    // Using DateTime.utc avoids double-conversion in _formatUtc.
    // IST is UTC+5:30 = +330 minutes.
    // To convert wall-clock IST to UTC: subtract 5h30m.
    final utcHour = hour - 5;
    final utcMinute = minute - 30;

    // Handle negative minute/hour overflow
    var year = date.year;
    var month = date.month;
    var day = date.day;
    var finalHour = utcHour;
    var finalMinute = utcMinute;

    if (finalMinute < 0) {
      finalMinute += 60;
      finalHour -= 1;
    }
    if (finalHour < 0) {
      finalHour += 24;
      day -= 1;
      // Handle day underflow (simplified — only for same-month dates)
      if (day < 1) {
        month -= 1;
        if (month < 1) {
          month = 12;
          year -= 1;
        }
        day = _daysInMonth(year, month);
      }
    }

    return DateTime.utc(year, month, day, finalHour, finalMinute);
  }

  static int _daysInMonth(int year, int month) {
    switch (month) {
      case 1:
        return 31;
      case 2:
        return _isLeapYear(year) ? 29 : 28;
      case 3:
        return 31;
      case 4:
        return 30;
      case 5:
        return 31;
      case 6:
        return 30;
      case 7:
        return 31;
      case 8:
        return 31;
      case 9:
        return 30;
      case 10:
        return 31;
      case 11:
        return 30;
      case 12:
        return 31;
      default:
        return 30;
    }
  }

  static bool _isLeapYear(int year) {
    if (year % 4 != 0) return false;
    if (year % 100 != 0) return true;
    return year % 400 == 0;
  }
}
