import 'dart:convert';
import '../../../booking/domain/booking.dart';

/// Outcome of attempting to validate a QR pass at venue check-in.
class CheckInResult {
  const CheckInResult({
    required this.success,
    required this.message,
    this.booking,
    this.checkedInAt,
  });

  final bool success;
  final String message;
  final Booking? booking;
  final DateTime? checkedInAt;
}

/// Structured digital check-in payload encoded into the 2D QR matrix.
///
/// Designed to be decoded by venue desk scanners, mobile cameras, or
/// manual verification terminals.
class BookingCheckInPayload {
  const BookingCheckInPayload({
    required this.bookingId,
    required this.bookingRef,
    required this.venueId,
    required this.venueName,
    required this.slotId,
    required this.slotLabel,
    required this.bookDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.token,
    this.issuedAt,
  });

  final String bookingId;
  final String bookingRef;
  final String venueId;
  final String venueName;
  final String slotId;
  final String slotLabel;
  final String bookDate;
  final String startTime;
  final String endTime;
  final String status;
  final String token;
  final DateTime? issuedAt;

  factory BookingCheckInPayload.fromBooking(Booking booking) {
    return BookingCheckInPayload(
      bookingId: booking.id,
      bookingRef: booking.bookingRef.isNotEmpty ? booking.bookingRef : 'BMS-${booking.id}',
      venueId: booking.venueId,
      venueName: booking.venueName.isNotEmpty ? booking.venueName : 'Space Reservation',
      slotId: booking.slotId,
      slotLabel: booking.slotLabel.isNotEmpty ? booking.slotLabel : 'Standard Slot',
      bookDate: booking.bookDate.toIso8601String().split('T').first,
      startTime: booking.displayStart,
      endTime: booking.displayEnd,
      status: booking.status.dbValue,
      token: 'BMS-PASS-${booking.id.replaceAll('-', '').takeLast(6).toUpperCase()}',
      issuedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'BOOKING_CHECK_IN',
    'booking_id': bookingId,
    'booking_ref': bookingRef,
    'venue_id': venueId,
    'venue_name': venueName,
    'slot_id': slotId,
    'slot_label': slotLabel,
    'book_date': bookDate,
    'start_time': startTime,
    'end_time': endTime,
    'status': status,
    'token': token,
    'issued_at': issuedAt?.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  static BookingCheckInPayload? tryParse(String raw) {
    final clean = raw.trim();
    if (!clean.startsWith('{')) return null;
    try {
      final map = jsonDecode(clean);
      if (map is! Map<String, dynamic>) return null;
      return BookingCheckInPayload(
        bookingId: map['booking_id'] as String? ?? '',
        bookingRef: map['booking_ref'] as String? ?? '',
        venueId: map['venue_id'] as String? ?? '',
        venueName: map['venue_name'] as String? ?? '',
        slotId: map['slot_id'] as String? ?? '',
        slotLabel: map['slot_label'] as String? ?? '',
        bookDate: map['book_date'] as String? ?? '',
        startTime: map['start_time'] as String? ?? '',
        endTime: map['end_time'] as String? ?? '',
        status: map['status'] as String? ?? 'confirmed',
        token: map['token'] as String? ?? '',
        issuedAt: DateTime.tryParse(map['issued_at'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}

extension on String {
  String takeLast(int n) {
    if (length <= n) return this;
    return substring(length - n);
  }
}
