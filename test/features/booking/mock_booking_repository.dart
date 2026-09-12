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
      BookingHold(id: 'hold-1', expiresAt: DateTime.now().add(Duration(minutes: holdMinutes)));

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
  Future<List<Booking>> myBookings() async => bookings;

  @override
  Future<List<Booking>> ownerVenueBookings() async => ownerBookings;

  @override
  Future<void> cancelBooking(String bookingId) async {}

  @override
  Future<Booking> checkInBooking(String qrOrRef) async {
    return bookings.first;
  }
}
