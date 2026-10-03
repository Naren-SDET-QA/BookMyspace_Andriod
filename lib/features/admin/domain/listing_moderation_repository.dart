import 'listing_moderation.dart';

abstract interface class ListingModerationRepository {
  Future<List<ModeratedListing>> listings({String? status});

  Future<ModeratedListing> moderate({
    required String venueId,
    required String action,
    String? reason,
  });

  Future<List<OversightRow>> bookings({int limit = 50});

  Future<List<OversightRow>> payments({int limit = 50});

  Future<List<OversightRow>> refunds({int limit = 50});

  /// Platform-admin cancellation of a **confirmed** booking through the
  /// `admin_cancel_booking` RPC (the only admin booking write the backend
  /// allows). [reason] is required; a positive [refundAmount] queues a
  /// refund against the captured payment, null/0 cancels without refund.
  Future<void> adminCancelBooking({
    required String bookingId,
    required String reason,
    double? refundAmount,
  });

  /// Platform-admin approval of a booking request in
  /// `awaiting_owner_approval`, through the existing `approve_venue_booking`
  /// RPC. The request moves to `pending` and still needs payment. Throws a
  /// `BusinessException` (code `ALREADY_PROCESSED`, `INVALID_STATUS`,
  /// `APPROVAL_EXPIRED`, `SLOT_UNAVAILABLE`, ...) when it cannot be approved.
  Future<void> adminApproveBooking(String bookingId);

  /// Platform-admin decline of a booking request in
  /// `awaiting_owner_approval`, through the existing `reject_venue_booking`
  /// RPC. [reason] is stored as the rejection reason and the hold is released.
  Future<void> adminRejectBooking(String bookingId, {required String reason});
}

abstract interface class ListingLifecycleRepository {
  Future<ModeratedListing> submitForReview(String venueId);
}
