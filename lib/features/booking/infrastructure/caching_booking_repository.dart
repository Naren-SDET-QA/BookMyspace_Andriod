import '../../../core/offline/offline_cache.dart';
import '../domain/booking.dart';
import '../domain/booking_repository.dart';

/// Caches my-bookings / booking-by-id for offline browsing.
///
/// Holds, availability, create, cancel and coupons always hit the live inner
/// repository so server enforcement stays authoritative.
class CachingBookingRepository implements BookingRepository {
  CachingBookingRepository(this._inner, this._cache, {this.cacheScope});

  final BookingRepository _inner;
  final OfflineCache _cache;
  final String? cacheScope;

  String get _bookingsKey => cacheScope == null
      ? OfflineCache.bookingsKey
      : '${OfflineCache.bookingsKey}.$cacheScope';

  @override
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  }) {
    return _inner.availableTimeSlots(venueId: venueId, date: date);
  }

  @override
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  }) {
    return _inner.acquireHold(
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      amount: amount,
      holdMinutes: holdMinutes,
    );
  }

  @override
  Future<Booking> createBooking({
    required BookingHold hold,
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    required double taxAmount,
    required double totalAmount,
    Map<String, dynamic> metadata = const {},
  }) {
    return _inner.createBooking(
      hold: hold,
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      amount: amount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      metadata: metadata,
    );
  }

  @override
  Future<Booking?> bookingById(String bookingId) async {
    try {
      final live = await _inner.bookingById(bookingId);
      if (live != null) {
        await _cache.saveBookings('$_bookingsKey.one.$bookingId', [live]);
      }
      return live;
    } catch (error) {
      if (!isOfflineWorthy(error)) rethrow;
      final cached = await _cache.loadBookings('$_bookingsKey.one.$bookingId');
      if (cached != null && cached.isNotEmpty) return cached.first;
      final mine = await _cache.loadBookings(_bookingsKey);
      final match = mine?.where((booking) => booking.id == bookingId);
      if (match != null && match.isNotEmpty) return match.first;
      rethrow;
    }
  }

  @override
  Future<List<Booking>> myBookings() {
    return _cache.readThroughBookings(_bookingsKey, _inner.myBookings);
  }

  @override
  Future<void> cancelBooking(String bookingId) =>
      _inner.cancelBooking(bookingId);

  @override
  Future<Booking> applyCoupon({
    required String bookingId,
    required String code,
  }) {
    return _inner.applyCoupon(bookingId: bookingId, code: code);
  }

  @override
  Future<Booking> removeCoupon(String bookingId) =>
      _inner.removeCoupon(bookingId);

  // Delegates for BookingRepository/VenueRepository members added by the
  // main lineage (no offline caching for these yet).
  @override
  Future<Booking> requestBooking({ required String venueId, required String slotId, required DateTime bookDate, required double amount, int approvalMinutes = 120, String? couponCode, }) =>
      _inner.requestBooking(venueId: venueId, slotId: slotId, bookDate: bookDate, amount: amount, approvalMinutes: approvalMinutes, couponCode: couponCode);

  @override
  Future<Booking> approveBooking(String bookingId) =>
      _inner.approveBooking(bookingId);

  @override
  Future<Booking> rejectBooking(String bookingId, {String? reason}) =>
      _inner.rejectBooking(bookingId, reason: reason);

  @override
  Future<List<Booking>> recentBookings({int limit = 5}) =>
      _inner.recentBookings(limit: limit);

  @override
  Future<List<Booking>> myBookingsPage({ required int offset, required int limit, }) =>
      _inner.myBookingsPage(offset: offset, limit: limit);

  @override
  Future<List<Booking>> ownerVenueBookings() =>
      _inner.ownerVenueBookings();

  @override
  Future<Booking> checkInBooking(String qrOrRef) =>
      _inner.checkInBooking(qrOrRef);
}
