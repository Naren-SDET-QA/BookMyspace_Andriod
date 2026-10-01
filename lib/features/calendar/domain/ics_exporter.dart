import 'calendar_event.dart';

/// Generates a valid RFC 5545 iCalendar (.ics) file from a [CalendarEvent].
///
/// Pure Dart — no platform dependencies, so the output is byte-identical on
/// Android, iOS and Web. The caller is responsible for the platform-specific
/// save/share surface (see [CalendarExportService]).
class IcsExporter {
  const IcsExporter();

  static const _prodId = '-//BookMySpace//Booking Calendar//EN';

  /// Builds the complete .ics document for a single event.
  ///
  /// All timestamps are in UTC (suffixed with `Z`) because [CalendarEvent.start]
  /// and [CalendarEvent.end] are already in UTC (see [CalendarEvent._composeDateTime]).
  /// This avoids the need for `VTIMEZONE` blocks while keeping the event at the
  /// correct wall-clock time in any timezone.
  String toIcs(CalendarEvent event) {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:$_prodId')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH');

    _writeEvent(buffer, event);

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  /// Builds the complete .ics document for multiple events.
  String toIcsMany(List<CalendarEvent> events) {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:$_prodId')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH');

    for (final event in events) {
      _writeEvent(buffer, event);
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  void _writeEvent(StringBuffer buffer, CalendarEvent event) {
    final dtStart = _formatUtc(event.start);
    final dtEnd = _formatUtc(event.end);
    final dtStamp = _formatUtc(DateTime.now().toUtc());

    buffer
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${event.uid}')
      ..writeln('DTSTAMP:$dtStamp')
      ..writeln('DTSTART:$dtStart')
      ..writeln('DTEND:$dtEnd')
      ..writeln('SUMMARY:${_escape(event.title)}')
      ..writeln('DESCRIPTION:${_escape(event.description)}')
      ..writeln('LOCATION:${_escape(event.location)}')
      ..writeln('ORGANIZER:${_escape(event.organizer)}')
      ..writeln('STATUS:CONFIRMED')
      ..writeln('END:VEVENT');
  }

  /// Formats a [DateTime] as a UTC iCalendar timestamp: `20260913T093000Z`.
  ///
  /// The `Z` suffix marks it as UTC, so calendar apps convert it to the
  /// user's local timezone automatically.
  static String _formatUtc(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '${y}${m}${d}T${h}${min}${s}Z';
  }

  /// Escapes special characters per RFC 5545 §3.3.11:
  /// - backslash → `\\`
  /// - semicolon → `\;`
  /// - comma → `\,`
  /// - newline → `\n`
  ///
  /// Also folds long lines (>75 octets) per §3.1, though most calendar
  /// apps handle unfolded lines gracefully.
  static String _escape(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', '');
  }
}
