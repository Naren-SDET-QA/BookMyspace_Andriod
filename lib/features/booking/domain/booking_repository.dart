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
  ///
  /// Unbounded by design -- existing callers (QR check-in pass eligibility,
  /// the profile screen) rely on seeing the complete history. New surfaces
  /// that only need a bounded slice should use [recentBookings] (a small
  /// fixed-size preview) or [myBookingsPage] (paginated) instead of adding
  /// more callers here.
  Future<List<Booking>> myBookings();

  /// Phase 9XM-3: a small, bounded slice of the signed-in user's most
  /// recent bookings (newest first), for surfaces like Home that only ever
  /// show a short preview and never need the full history.
  Future<List<Booking>> recentBookings({int limit = 5});

  /// Phase 9XM-3: one page of the signed-in user's bookings, newest first,
  /// ordered deterministically (book_date desc, start_time desc, id asc as
  /// a tiebreaker) so consecutive pages neither duplicate nor skip rows.
  /// Used by the paginated My Bookings screen instead of [myBookings].
  Future<List<Booking>> myBookingsPage({
    required int offset,
    required int limit,
  });

  /// Phase 9XM-3: fetches exactly one booking owned by the signed-in user
  /// directly by id (RLS-scoped, same as every other query here), so
  /// booking-detail lookups don't depend on that booking being present in
  /// whatever page of [myBookingsPage] happens to be loaded. Returns null
  /// if the booking doesn't exist or isn't visible to the caller -- never
  /// invents a row, matching [myBookings]'s existing contract.
  Future<Booking?> bookingById(String bookingId);

  /// Bookings visible to the signed-in venue owner through RLS
  /// (their venues, not a client-side role bypass).
  Future<List<Booking>> ownerVenueBookings();

  /// Cancels a booking still in `pending` status.
  Future<void> cancelBooking(String bookingId);

  /// Validates and marks a booking as checked-in / completed using QR code or booking reference.
  Future<Booking> checkInBooking(String qrOrRef);
}
