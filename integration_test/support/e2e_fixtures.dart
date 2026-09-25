import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';

import '../../test/features/booking/mock_booking_repository_release.dart';

/// Deterministic mock-mode data. These ids come from the shared test mocks
/// in `test/features/**/mock_*_repository.dart` and are mirrored for
/// Playwright in `e2e-playwright/support/fixtures.ts`.
abstract final class E2eFixtures {
  static const customer = AuthUser(
    id: 'e2e-customer',
    email: 'e2e.customer@bookmyspace.test',
    // Pre-fills the booking form, so it must pass the app's validators:
    // name = letters/spaces only, and function halls require a phone.
    fullName: 'Test Customer',
    phone: '9876543210',
  );

  /// Venue owner of [venueId]. The role stands in for the backend
  /// `profiles.role`; mock sign-in returns it, the client never sets it.
  static const owner = AuthUser(
    id: 'e2e-owner',
    email: 'e2e.owner@bookmyspace.test',
    fullName: 'Test Owner',
    phone: '9876500000',
    role: UserRole.venueOwner,
  );

  static const admin = AuthUser(
    id: 'e2e-admin',
    email: 'e2e.admin@bookmyspace.test',
    fullName: 'Test Admin',
    role: UserRole.admin,
  );

  /// Mock mode accepts any credentials; this is not a real secret.
  static const mockPassword = 'mock-only-password';
  static const mockOtp = '123456';

  static const venueId = 'v1';
  static const venueName = 'Sunrise Function Hall';
  static const venueSearchQuery = 'Sunrise';
  static const availableSlotId = 's1';
  static const unavailableSlotId = 's2';
  static const seededBookingId = 'b1';

  /// Seeded bookings for the lifecycle / refund / stale-hold journeys.
  static const approvalBookingId = 'b-approval';
  static const confirmedBookingId = 'b-confirmed';
  static const staleHoldBookingId = 'b-stale';

  /// Function halls require an event type before a hold can be taken.
  static const eventType = 'Wedding';

  /// Owner time slot created by the availability journey (label = row id).
  static const newSlotLabel = 'E2E';

  /// A booking of [venueId] in [status], built from the shared sample.
  static Booking seededBooking(
    String id,
    BookingStatus status, {
    String paymentMethod = '',
    Map<String, dynamic> metadata = const {},
  }) {
    final base = MockBookingRepository.sampleBooking(id: id, status: status);
    return Booking(
      id: base.id,
      bookingRef: 'BMS-${id.toUpperCase()}',
      venueId: base.venueId,
      slotId: base.slotId,
      bookDate: base.bookDate,
      startTime: base.startTime,
      endTime: base.endTime,
      status: status,
      amount: base.amount,
      taxAmount: base.taxAmount,
      totalAmount: base.totalAmount,
      venueName: base.venueName,
      slotLabel: base.slotLabel,
      customerName: customer.fullName,
      customerPhone: customer.phone,
      paymentMethod: paymentMethod,
      metadata: metadata,
    );
  }
}
