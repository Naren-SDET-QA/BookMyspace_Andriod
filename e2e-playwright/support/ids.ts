/**
 * Mirror of `E2eIds` in lib/core/widgets/test_id.dart.
 * Kept in sync by test/tool/e2e_ids_contract_test.dart — change both together.
 */
export const Ids = {
  loginEmail: 'login_email',
  loginPassword: 'login_password',
  loginSubmit: 'login_submit',
  loginError: 'login_error',
  loginForgotPassword: 'login_forgot_password',
  loginRegister: 'login_register',
  otpChannel: 'otp_channel',
  otpContact: 'otp_contact',
  otpSend: 'otp_send',
  otpCode: 'otp_code',
  otpSubmit: 'otp_submit',
  logout: 'logout',
  searchInput: 'search_input',
  venueFavorite: 'venue_favorite',
  bookNow: 'book_now',
  bookingEventType: 'booking_event_type',
  slotPicker: 'slot_picker',
  bookingConfirm: 'booking_confirm',
  bookingConfirmDialog: 'booking_confirm_dialog',
  bookingSignIn: 'booking_sign_in',
  bookingHistory: 'booking_history',
  bookingCancelConfirm: 'booking_cancel_confirm',
  checkoutSummary: 'checkout_summary',
  nav: (destinationId: string) => `nav_${destinationId}`,
  venueCard: (venueId: string) => `venue_card_${venueId}`,
  slot: (slotId: string) => `slot_${slotId}`,
  bookingCard: (bookingId: string) => `booking_card_${bookingId}`,
  bookingCancel: (bookingId: string) => `booking_cancel_${bookingId}`,
} as const;

export const Tab = { home: 'home', search: 'search', bookings: 'bookings', profile: 'profile' } as const;
