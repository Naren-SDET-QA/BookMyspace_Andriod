import 'package:bookmyspace/features/auth/domain/auth_user.dart';

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

  /// Mock mode accepts any credentials; this is not a real secret.
  static const mockPassword = 'mock-only-password';
  static const mockOtp = '123456';

  static const venueId = 'v1';
  static const venueName = 'Sunrise Function Hall';
  static const venueSearchQuery = 'Sunrise';
  static const availableSlotId = 's1';
  static const unavailableSlotId = 's2';
  static const seededBookingId = 'b1';

  /// Function halls require an event type before a hold can be taken.
  static const eventType = 'Wedding';
}
