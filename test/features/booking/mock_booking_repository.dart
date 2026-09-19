import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/domain/booking_repository.dart';

class MockBookingRepository implements BookingRepository {
  MockBookingRepository({
    this.bookings = const [],
    this.ownerBookings = const [],
  });

  List<Booking> bookings;
  List<Booking> ownerBookings;

  @override
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  }) async =>
      const [];

  @override
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  }) async =>
      BookingHold(
          id: 'hold-1',
          expiresAt: DateTime.now().add(Duration(minutes: holdMinutes)));

  @override
  Future<Booking> requestBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int approvalMinutes = 120,
  }) async {
    return Booking(
      id: 'b-request-1',
      bookingRef: 'BMS-REQUEST-1',
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      startTime: '09:00:00',
      endTime: '12:00:00',
      status: BookingStatus.awaitingOwnerApproval,
      amount: amount,
      taxAmount: 0,
      totalAmount: amount,
      approvalRequestedAt: DateTime.now(),
      approvalExpiresAt: DateTime.now().add(Duration(minutes: approvalMinutes)),
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
  }) async {
    return Booking(
      id: 'b1',
      bookingRef: 'BMS-1',
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      startTime: '09:00:00',
      endTime: '12:00:00',
      status: BookingStatus.pending,
      amount: amount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
    );
  }

  @override
  Future<Booking> approveBooking(String bookingId) async {
    return bookings.firstWhere(
      (booking) => booking.id == bookingId,
      orElse: () => throw StateError('booking not found'),
    );
  }

  @override
  Future<Booking> rejectBooking(String bookingId, {String? reason}) async {
    return bookings.firstWhere(
      (booking) => booking.id == bookingId,
      orElse: () => throw StateError('booking not found'),
    );
  }

  @override
  Future<List<Booking>> myBookings() async => bookings;

  // Phase 9XM-3: minimal mock support for the new bounded/paginated/by-id
  // repository methods, added so this mock keeps implementing
  // BookingRepository after the interface grew these methods. Behavior
  // mirrors myBookings() as closely as makes sense for a test double.
  @override
  Future<List<Booking>> recentBookings({int limit = 5}) async =>
      bookings.take(limit).toList();

  @override
  Future<List<Booking>> myBookingsPage({
    required int offset,
    required int limit,
  }) async {
    if (offset >= bookings.length) return const [];
    final end = (offset + limit).clamp(0, bookings.length);
    return bookings.sublist(offset, end);
  }

  @override
  Future<Booking?> bookingById(String bookingId) async {
    for (final booking in bookings) {
      if (booking.id == bookingId) return booking;
    }
    return null;
  }

  @override
  Future<List<Booking>> ownerVenueBookings() async => ownerBookings;

  @override
  Future<void> cancelBooking(String bookingId) async {}

  @override
  Future<Booking> checkInBooking(String qrOrRef) async {
    return bookings.first;
  }
}
