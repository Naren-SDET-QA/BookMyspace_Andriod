import 'package:bookmyspace/core/errors/app_exceptions.dart' as app_errors;
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner_bookings/domain/owner_booking_repository.dart';

/// In-memory owner booking repository for tests.
class MockOwnerBookingRepository implements OwnerBookingRepository {
  MockOwnerBookingRepository({List<Booking>? bookings})
    : _bookings = bookings ?? [];

  final List<Booking> _bookings;

  bool failCreateOffline = false;
  bool failUpdateStatus = false;
  bool failDecideBooking = false;
  Object? decideBookingError;
  String? decideBookingRefundStatus;
  Booking? lastCreated;
  String? lastUpdatedBookingId;
  OwnerBookingAction? lastAction;
  String? lastDecidedBookingId;
  OwnerBookingDecision? lastDecision;
  String? lastDecisionReason;
  int decideCalls = 0;

  @override
  Future<List<Booking>> myVenueBookings() async => List.of(_bookings);

  @override
  Future<Booking> createOfflineBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required String customerName,
    required String customerPhone,
    required double amount,
    required double taxAmount,
    required double totalAmount,
  }) async {
    if (failCreateOffline) throw Exception('create failed');
    final booking = Booking(
      id: 'off-1',
      bookingRef: 'BMS-OFF01',
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      startTime: '09:00:00',
      endTime: '13:00:00',
      status: BookingStatus.confirmed,
      amount: amount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      venueName: 'Sunrise Function Hall',
      customerName: customerName,
      customerPhone: customerPhone,
      isOffline: true,
      paymentMethod: 'offline',
    );
    lastCreated = booking;
    _bookings.insert(0, booking);
    return booking;
  }

  @override
  Future<Booking> updateStatus(
    String bookingId,
    OwnerBookingAction action,
  ) async {
    if (failUpdateStatus) throw Exception('update failed');
    lastUpdatedBookingId = bookingId;
    lastAction = action;
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index < 0) throw Exception('Booking not found: $bookingId');
    final next = switch (action) {
      OwnerBookingAction.confirm => BookingStatus.confirmed,
      OwnerBookingAction.complete => BookingStatus.completed,
      OwnerBookingAction.cancel => BookingStatus.cancelled,
      OwnerBookingAction.noShow => BookingStatus.noShow,
    };
    final current = _bookings[index];
    _bookings[index] = Booking(
      id: current.id,
      bookingRef: current.bookingRef,
      venueId: current.venueId,
      slotId: current.slotId,
      bookDate: current.bookDate,
      startTime: current.startTime,
      endTime: current.endTime,
      status: next,
      amount: current.amount,
      taxAmount: current.taxAmount,
      totalAmount: current.totalAmount,
      venueName: current.venueName,
      venueCity: current.venueCity,
      slotLabel: current.slotLabel,
      customerName: current.customerName,
      customerPhone: current.customerPhone,
      isOffline: current.isOffline,
      paymentMethod: current.paymentMethod,
      paymentRef: current.paymentRef,
      paidAt: current.paidAt,
      metadata: current.metadata,
    );
    return _bookings[index];
  }

  /// Read access for assertions.
  Booking bookingById(String id) => _bookings.firstWhere((b) => b.id == id);

  /// Simulates a decision made by someone else (e.g. an administrator)
  /// after the owner's list was loaded.
  void decideElsewhere(String bookingId, BookingStatus status) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    _bookings[index] = _withStatus(_bookings[index], status);
  }

  /// Mirrors SupabaseOwnerBookingRepository.decideBooking:
  /// * `awaiting_owner_approval` goes through approve_venue_booking /
  ///   reject_venue_booking: approve moves the request to `pending`
  ///   (waiting for payment, never `confirmed`), reject to `owner_rejected`.
  /// * legacy `pending_owner_approval` goes through owner-booking-manage:
  ///   approve -> confirmed, reject -> rejected.
  /// * anything else was already decided: the RPCs answer ALREADY_PROCESSED
  ///   (already approved) or INVALID_STATUS, mapped to the same
  ///   BusinessException messages as the real repository. Rejecting an
  ///   already rejected/expired/cancelled request is idempotent.
  @override
  Future<BookingDecisionOutcome> decideBooking(
    String bookingId,
    OwnerBookingDecision decision, {
    String? reason,
  }) async {
    lastDecidedBookingId = bookingId;
    lastDecision = decision;
    lastDecisionReason = reason;
    decideCalls++;
    if (failDecideBooking) {
      throw decideBookingError ?? Exception('decide failed');
    }
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index < 0) throw Exception('Booking not found: $bookingId');
    final current = _bookings[index];
    final isApprove = decision == OwnerBookingDecision.approve;
    final BookingStatus next;
    switch (current.status) {
      case BookingStatus.awaitingOwnerApproval:
        next = isApprove ? BookingStatus.pending : BookingStatus.ownerRejected;
      case BookingStatus.pendingOwnerApproval:
        next = isApprove ? BookingStatus.confirmed : BookingStatus.rejected;
      case BookingStatus.ownerRejected ||
              BookingStatus.approvalExpired ||
              BookingStatus.cancelled
          when !isApprove:
        return BookingDecisionOutcome(booking: current);
      case BookingStatus.pending when isApprove:
        throw const app_errors.BusinessException(
          'This request has already been processed.',
          code: 'ALREADY_PROCESSED',
        );
      default:
        throw const app_errors.BusinessException(
          'This booking cannot be moved to that status.',
          code: 'INVALID_STATUS',
        );
    }
    final updated = _withStatus(
      current,
      next,
      rejectionReason: isApprove ? null : reason,
    );
    _bookings[index] = updated;
    return BookingDecisionOutcome(
      booking: updated,
      refundStatus: isApprove ? null : decideBookingRefundStatus,
    );
  }

  static Booking _withStatus(
    Booking current,
    BookingStatus next, {
    String? rejectionReason,
  }) {
    return Booking(
      id: current.id,
      bookingRef: current.bookingRef,
      venueId: current.venueId,
      slotId: current.slotId,
      bookDate: current.bookDate,
      startTime: current.startTime,
      endTime: current.endTime,
      status: next,
      amount: current.amount,
      taxAmount: current.taxAmount,
      totalAmount: current.totalAmount,
      venueName: current.venueName,
      venueCity: current.venueCity,
      slotLabel: current.slotLabel,
      customerName: current.customerName,
      customerPhone: current.customerPhone,
      isOffline: current.isOffline,
      paymentMethod: current.paymentMethod,
      paymentRef: current.paymentRef,
      paidAt: current.paidAt,
      metadata: current.metadata,
      rejectionReason: rejectionReason ?? current.rejectionReason,
    );
  }
}
