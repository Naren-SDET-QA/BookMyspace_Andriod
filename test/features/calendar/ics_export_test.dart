import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/calendar/domain/calendar_event.dart';
import 'package:bookmyspace/features/calendar/domain/ics_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarEvent.fromBooking', () {
    test('returns null for booking with empty id', () {
      final booking = _makeBooking(id: '', status: BookingStatus.confirmed);
      expect(CalendarEvent.fromBooking(booking), isNull);
    });

    test('returns null for booking with no start time', () {
      final booking = _makeBooking(
        id: 'b1',
        startTime: '',
        status: BookingStatus.confirmed,
      );
      expect(CalendarEvent.fromBooking(booking), isNull);
    });

    test('returns event for confirmed booking', () {
      final booking = _makeBooking(
        id: 'b1',
        status: BookingStatus.confirmed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event, isNotNull);
      expect(event!.uid, 'b1@bookmyspace.app');
    });

    test('returns event for completed booking', () {
      final booking = _makeBooking(
        id: 'b2',
        status: BookingStatus.completed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event, isNotNull);
      expect(event!.uid, 'b2@bookmyspace.app');
    });

    test('title includes venue name and slot label', () {
      final booking = _makeBooking(
        id: 'b3',
        venueName: 'CoWork Hub',
        slotLabel: 'Morning Slot',
        status: BookingStatus.confirmed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event!.title, 'CoWork Hub — Morning Slot');
    });

    test('title falls back to "Venue Booking" when venue name is empty', () {
      final booking = _makeBooking(
        id: 'b4',
        venueName: '',
        slotLabel: '',
        status: BookingStatus.confirmed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event!.title, 'Venue Booking — Booking');
    });

    test('start time is correctly converted from IST to UTC', () {
      // Booking date 2026-09-15, start time "09:00:00" IST
      // IST is UTC+5:30, so 09:00 IST = 03:30 UTC
      final booking = _makeBooking(
        id: 'b5',
        bookDate: DateTime(2026, 9, 15),
        startTime: '09:00:00',
        endTime: '10:00:00',
        status: BookingStatus.confirmed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event, isNotNull);
      expect(event!.start.hour, 3);
      expect(event.start.minute, 30);
      expect(event.start.year, 2026);
      expect(event.start.month, 9);
      expect(event.start.day, 15);
    });

    test('end time is correctly converted from IST to UTC', () {
      // 17:00 IST = 11:30 UTC
      final booking = _makeBooking(
        id: 'b6',
        bookDate: DateTime(2026, 9, 15),
        startTime: '17:00:00',
        endTime: '18:00:00',
        status: BookingStatus.confirmed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event!.end.hour, 12);
      expect(event.end.minute, 30);
    });

    test('returns null when end time is not after start time', () {
      // start 10:00, end 10:00 — same time, not after
      final booking = _makeBooking(
        id: 'b7',
        bookDate: DateTime(2026, 9, 15),
        startTime: '10:00:00',
        endTime: '10:00:00',
        status: BookingStatus.confirmed,
      );
      expect(CalendarEvent.fromBooking(booking), isNull);
    });

    test('returns null for invalid time format', () {
      final booking = _makeBooking(
        id: 'b8',
        startTime: 'not-a-time',
        endTime: 'not-a-time',
        status: BookingStatus.confirmed,
      );
      expect(CalendarEvent.fromBooking(booking), isNull);
    });

    test('description includes booking ref, status, slot, and amount', () {
      final booking = _makeBooking(
        id: 'b9',
        bookingRef: 'BMS-2026-001',
        slotLabel: 'Desk 5',
        totalAmount: 1500.0,
        status: BookingStatus.confirmed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event!.description, contains('BMS-2026-001'));
      expect(event.description, contains('confirmed'));
      expect(event.description, contains('Desk 5'));
      expect(event.description, contains('1500'));
    });

    test('UID is deterministic for the same booking id', () {
      final booking = _makeBooking(id: 'b10', status: BookingStatus.confirmed);
      final event1 = CalendarEvent.fromBooking(booking);
      final event2 = CalendarEvent.fromBooking(booking);
      expect(event1!.uid, event2!.uid);
    });

    test('location falls back when venueCity is empty', () {
      final booking = _makeBooking(
        id: 'b11',
        venueCity: '',
        status: BookingStatus.confirmed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event!.location, 'See booking details');
    });

    test('location uses venue city when present', () {
      final booking = _makeBooking(
        id: 'b12',
        venueCity: 'Hyderabad',
        status: BookingStatus.confirmed,
      );
      final event = CalendarEvent.fromBooking(booking);
      expect(event!.location, 'Hyderabad');
    });
  });

  group('Booking.canExportCalendar', () {
    test('confirmed bookings can export', () {
      final booking = _makeBooking(status: BookingStatus.confirmed);
      expect(booking.canExportCalendar, isTrue);
    });

    test('completed bookings can export', () {
      final booking = _makeBooking(status: BookingStatus.completed);
      expect(booking.canExportCalendar, isTrue);
    });

    test('cancelled bookings cannot export', () {
      final booking = _makeBooking(status: BookingStatus.cancelled);
      expect(booking.canExportCalendar, isFalse);
    });

    test('rejected bookings cannot export', () {
      final booking = _makeBooking(status: BookingStatus.ownerRejected);
      expect(booking.canExportCalendar, isFalse);
    });

    test('expired approval bookings cannot export', () {
      final booking = _makeBooking(status: BookingStatus.approvalExpired);
      expect(booking.canExportCalendar, isFalse);
    });

    test('held bookings cannot export', () {
      final booking = _makeBooking(status: BookingStatus.held);
      expect(booking.canExportCalendar, isFalse);
    });

    test('pending bookings cannot export', () {
      final booking = _makeBooking(status: BookingStatus.pending);
      expect(booking.canExportCalendar, isFalse);
    });

    test('refunded bookings cannot export', () {
      final booking = _makeBooking(status: BookingStatus.refunded);
      expect(booking.canExportCalendar, isFalse);
    });

    test('no-show bookings cannot export', () {
      final booking = _makeBooking(status: BookingStatus.noShow);
      expect(booking.canExportCalendar, isFalse);
    });
  });

  group('IcsExporter', () {
    const exporter = IcsExporter();

    test('produces valid VCALENDAR structure', () {
      final event = _makeEvent();
      final ics = exporter.toIcs(event);

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('END:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('PRODID:-//BookMySpace//Booking Calendar//EN'));
      expect(ics, contains('CALSCALE:GREGORIAN'));
      expect(ics, contains('METHOD:PUBLISH'));
    });

    test('produces a VEVENT block', () {
      final event = _makeEvent();
      final ics = exporter.toIcs(event);

      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('END:VEVENT'));
    });

    test('UID property contains the event uid', () {
      final event = _makeEvent(uid: 'test-uid@bookmyspace.app');
      final ics = exporter.toIcs(event);

      expect(ics, contains('UID:test-uid@bookmyspace.app'));
    });

    test('DTSTART is in UTC (ends with Z)', () {
      final event = _makeEvent(
        start: DateTime.utc(2026, 9, 15, 3, 30, 0),
      );
      final ics = exporter.toIcs(event);

      expect(ics, contains('DTSTART:20260915T033000Z'));
    });

    test('DTEND is in UTC (ends with Z)', () {
      final event = _makeEvent(
        start: DateTime.utc(2026, 9, 15, 3, 30, 0),
        end: DateTime.utc(2026, 9, 15, 4, 30, 0),
      );
      final ics = exporter.toIcs(event);

      expect(ics, contains('DTEND:20260915T043000Z'));
    });

    test('DTSTAMP is in UTC and has Z suffix', () {
      final event = _makeEvent();
      final ics = exporter.toIcs(event);

      // DTSTAMP is set to DateTime.now().toUtc() inside the exporter
      final dtstampLine = ics
          .split('\n')
          .where((l) => l.startsWith('DTSTAMP:'))
          .first;
      expect(dtstampLine.endsWith('Z'), isTrue);
      // Format: DTSTAMP:YYYYMMDDTHHMMSSZ (8 + 16 = 24 chars)
      expect(dtstampLine.length, 24);
    });

    test('SUMMARY contains the event title', () {
      final event = _makeEvent(title: 'Team Meeting');
      final ics = exporter.toIcs(event);

      expect(ics, contains('SUMMARY:Team Meeting'));
    });

    test('DESCRIPTION contains the event description', () {
      final event = _makeEvent(description: 'Line 1\nLine 2');
      final ics = exporter.toIcs(event);

      // Newlines are escaped as \n per RFC 5545
      expect(ics, contains(r'DESCRIPTION:Line 1\nLine 2'));
    });

    test('LOCATION contains the event location', () {
      final event = _makeEvent(location: 'Hyderabad');
      final ics = exporter.toIcs(event);

      expect(ics, contains('LOCATION:Hyderabad'));
    });

    test('ORGANIZER contains the organizer email', () {
      final event = _makeEvent(organizer: 'noreply@bookmyspace.app');
      final ics = exporter.toIcs(event);

      expect(ics, contains('ORGANIZER:noreply@bookmyspace.app'));
    });

    test('STATUS is CONFIRMED', () {
      final event = _makeEvent();
      final ics = exporter.toIcs(event);

      expect(ics, contains('STATUS:CONFIRMED'));
    });

    test('escapes semicolons in text fields', () {
      final event = _makeEvent(title: 'A;B;C');
      final ics = exporter.toIcs(event);

      expect(ics, contains(r'SUMMARY:A\;B\;C'));
    });

    test('escapes commas in text fields', () {
      final event = _makeEvent(title: 'A,B,C');
      final ics = exporter.toIcs(event);

      expect(ics, contains(r'SUMMARY:A\,B\,C'));
    });

    test('escapes backslashes in text fields', () {
      final event = _makeEvent(title: r'A\B\C');
      final ics = exporter.toIcs(event);

      expect(ics, contains(r'SUMMARY:A\\B\\C'));
    });

    test('toIcsMany produces multiple VEVENT blocks', () {
      final events = [
        _makeEvent(uid: 'e1@bookmyspace.app'),
        _makeEvent(uid: 'e2@bookmyspace.app'),
      ];
      final ics = exporter.toIcsMany(events);

      expect(ics, contains('UID:e1@bookmyspace.app'));
      expect(ics, contains('UID:e2@bookmyspace.app'));
      // Two VEVENT blocks
      final veventCount = 'BEGIN:VEVENT'.allMatches(ics).length;
      expect(veventCount, 2);
    });

    test('ICS output is parseable: VCALENDAR wraps VEVENT', () {
      final event = _makeEvent();
      final ics = exporter.toIcs(event);
      final lines = ics.trim().split('\n');

      expect(lines.first, 'BEGIN:VCALENDAR');
      expect(lines.last, 'END:VCALENDAR');
      // VEVENT must be inside VCALENDAR
      final beginCal = lines.indexOf('BEGIN:VCALENDAR');
      final beginEvent = lines.indexOf('BEGIN:VEVENT');
      final endEvent = lines.indexOf('END:VEVENT');
      final endCal = lines.indexOf('END:VCALENDAR');
      expect(beginCal < beginEvent, isTrue);
      expect(beginEvent < endEvent, isTrue);
      expect(endEvent < endCal, isTrue);
    });
  });

  group('ICS end-to-end from Booking', () {
    test('confirmed booking produces a valid ICS with correct timestamps', () {
      final booking = _makeBooking(
        id: 'bms-123',
        bookingRef: 'BMS-2026-456',
        venueName: 'Tech Park Hub',
        venueCity: 'Bengaluru',
        slotLabel: 'Conference Room A',
        bookDate: DateTime(2026, 9, 20),
        startTime: '14:00:00',
        endTime: '16:00:00',
        totalAmount: 2000.0,
        status: BookingStatus.confirmed,
      );

      final event = CalendarEvent.fromBooking(booking);
      expect(event, isNotNull);

      const exporter = IcsExporter();
      final ics = exporter.toIcs(event!);

      // UID
      expect(ics, contains('UID:bms-123@bookmyspace.app'));
      // DTSTART: 14:00 IST = 08:30 UTC
      expect(ics, contains('DTSTART:20260920T083000Z'));
      // DTEND: 16:00 IST = 10:30 UTC
      expect(ics, contains('DTEND:20260920T103000Z'));
      // SUMMARY
      expect(ics, contains('SUMMARY:Tech Park Hub — Conference Room A'));
      // LOCATION
      expect(ics, contains('LOCATION:Bengaluru'));
      // DESCRIPTION contains booking ref
      expect(ics, contains('BMS-2026-456'));
    });

    test(
        'cancelled booking produces no ICS because canExportCalendar is false',
        () {
      final booking = _makeBooking(
        id: 'bms-cancelled',
        status: BookingStatus.cancelled,
      );

      // canExportCalendar is the gate — the export service checks it first
      expect(booking.canExportCalendar, isFalse);
    });
  });
}

/// Builds a [Booking] with sensible defaults for testing.
Booking _makeBooking({
  String id = 'test-booking',
  String bookingRef = 'BMS-TEST',
  String venueName = 'Test Venue',
  String venueCity = 'Test City',
  String slotLabel = 'Test Slot',
  DateTime? bookDate,
  String startTime = '09:00:00',
  String endTime = '10:00:00',
  BookingStatus status = BookingStatus.confirmed,
  double totalAmount = 1000.0,
}) {
  return Booking(
    id: id,
    bookingRef: bookingRef,
    venueId: 'v1',
    slotId: 's1',
    bookDate: bookDate ?? DateTime(2026, 9, 15),
    startTime: startTime,
    endTime: endTime,
    status: status,
    amount: totalAmount,
    taxAmount: 0,
    totalAmount: totalAmount,
    venueName: venueName,
    venueCity: venueCity,
    slotLabel: slotLabel,
  );
}

/// Builds a [CalendarEvent] with sensible defaults for testing.
CalendarEvent _makeEvent({
  String uid = 'test@bookmyspace.app',
  String title = 'Test Event',
  String description = 'Test Description',
  String location = 'Test Location',
  DateTime? start,
  DateTime? end,
  String organizer = 'noreply@bookmyspace.app',
}) {
  return CalendarEvent(
    uid: uid,
    title: title,
    description: description,
    location: location,
    start: start ?? DateTime.utc(2026, 9, 15, 3, 30, 0),
    end: end ?? DateTime.utc(2026, 9, 15, 4, 30, 0),
    organizer: organizer,
  );
}
