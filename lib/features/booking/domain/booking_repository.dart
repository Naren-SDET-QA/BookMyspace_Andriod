import '../domain/booking.dart';

/// Contract for the booking flow.
///
/// The implementation talks to Supabase (PostgREST + Edge Functions). The
/// atomic slot lock and owner-approval transition live server-side in
/// `request_venue_booking`, which this repository reaches through the
/// backwards-compatible `create-booking-hold` Edge Function. The client never
/// needs the service role.
abstract interface class BookingRepository {
  /// Lists every active slot of [venueId] with availability for [date].
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  });

  /// Atomically reserves [slotId] on [date] for the current user.
  ///
  /// Throws a [BookingConflictException] when the slot is taken. The returned
  /// hold expires after `holdMinutes` unless the booking is confirmed.
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  });

  /// Creates the customer request after the server rechecks the exact venue,
  /// date, slot and live inventory. The returned booking is never confirmed
  /// at this point; it is awaiting the venue owner's decision.
  Future<Booking> requestBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int approvalMinutes = 120,
  });

  /// Compatibility wrapper for older callers. New rows are created atomically
  /// by [acquireHold]/[requestBooking]; this method must never insert a row.
  Future<Booking> createBooking({
    required BookingHold hold,
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    required double taxAmount,
    required double totalAmount,
  });

  /// Accepts a request through the server-side owner authorization gate.
  Future<Booking> approveBooking(String bookingId);

  /// Rejects a request and releases its server-side hold.
  Future<Booking> rejectBooking(String bookingId, {String? reason});

  /// Bookings for the signed-in user, newest first.
  Future<List<Booking>> myBookings();

  /// Bookings visible to the signed-in venue owner through RLS
  /// (their venues, not a client-side role bypass).
  Future<List<Booking>> ownerVenueBookings();

  /// Cancels a booking still in `pending` status.
  Future<void> cancelBooking(String bookingId);

  /// Validates and marks a booking as checked-in / completed using QR code or booking reference.
  Future<Booking> checkInBooking(String qrOrRef);
}
