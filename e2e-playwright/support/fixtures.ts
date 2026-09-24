/**
 * Mock-mode data. Mirrors integration_test/support/e2e_fixtures.dart, which
 * in turn uses the shared mock repositories under test/features/.
 * Mock mode accepts any credentials — none of these are secrets.
 */
export const Fixtures = {
  customerEmail: 'e2e.customer@bookmyspace.test',
  mockPassword: 'mock-only-password',
  mockOtp: '123456',
  venueId: 'v1',
  venueSearchQuery: 'Sunrise',
  availableSlotId: 's1',
  unavailableSlotId: 's2',
  seededBookingId: 'b1',
  /** Function halls require an event type before a hold can be taken. */
  eventType: 'Wedding',
} as const;

/** Scenario names understood by integration_test/web_mock_main.dart. */
export type MockScenario =
  | 'signedOut'
  | 'signedIn'
  | 'withBookings'
  | 'invalidLogin'
  | 'invalidOtp'
  | 'networkFailure'
  | 'slotTaken';
