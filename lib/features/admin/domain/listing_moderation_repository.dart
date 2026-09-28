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
}

abstract interface class ListingLifecycleRepository {
  Future<ModeratedListing> submitForReview(String venueId);
}
