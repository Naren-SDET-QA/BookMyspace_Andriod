import 'package:flutter/widgets.dart';

/// Stable end-to-end identifiers for interactive UI.
///
/// Every id is exposed twice by [TestId]: as a `ValueKey<String>` (found by
/// Flutter `integration_test` via `find.byKey`) and as a semantics
/// `identifier` (rendered by Flutter web as the `flt-semantics-identifier`
/// DOM attribute that Playwright targets). The Playwright copy of this list
/// lives in `e2e-playwright/support/ids.ts` and is kept in sync by
/// `test/tool/e2e_ids_contract_test.dart`.
///
/// These are test hooks only: they never change layout, behaviour, or the
/// accessible labels users hear.
abstract final class E2eIds {
  // Auth: password login.
  static const loginEmail = 'login_email';
  static const loginPassword = 'login_password';
  static const loginSubmit = 'login_submit';
  static const loginError = 'login_error';
  static const loginForgotPassword = 'login_forgot_password';
  static const loginRegister = 'login_register';

  // Auth: OTP login.
  static const otpChannel = 'otp_channel';
  static const otpContact = 'otp_contact';
  static const otpSend = 'otp_send';
  static const otpCode = 'otp_code';
  static const otpSubmit = 'otp_submit';

  // Profile.
  static const logout = 'logout';

  // Discovery.
  static const searchInput = 'search_input';
  static const venueFavorite = 'venue_favorite';
  static const bookNow = 'book_now';

  // Booking.
  static const bookingEventType = 'booking_event_type';
  static const slotPicker = 'slot_picker';
  static const bookingConfirm = 'booking_confirm';
  static const bookingConfirmDialog = 'booking_confirm_dialog';
  static const bookingSignIn = 'booking_sign_in';
  static const bookingHistory = 'booking_history';
  static const bookingCancelConfirm = 'booking_cancel_confirm';

  // Booking history.
  static const bookingsTabUpcoming = 'bookings_tab_upcoming';
  static const bookingsTabCompleted = 'bookings_tab_completed';
  static const bookingsTabCancelled = 'bookings_tab_cancelled';
  static const bookingRefundConfirm = 'booking_refund_confirm';

  // Checkout / payment.
  static const checkoutSummary = 'checkout_summary';
  static const paymentMethodOnline = 'payment_method_online';
  static const paymentMethodVenue = 'payment_method_venue';
  static const paymentPay = 'payment_pay';
  static const paymentMessage = 'payment_message';
  static const paymentVerifying = 'payment_verifying';
  static const paymentPending = 'payment_pending';
  static const paymentError = 'payment_error';
  static const paymentDone = 'payment_done';
  static const holdExpired = 'hold_expired';
  static const bookingSuccess = 'booking_success';

  // Shared error state (ErrorView).
  static const errorRetry = 'error_retry';

  // Role entry points on the profile screen.
  static const profileOwnerDashboard = 'profile_owner_dashboard';
  static const profileAdminDashboard = 'profile_admin_dashboard';

  // Owner.
  static const ownerDashboard = 'owner_dashboard';
  static const ownerActionBookings = 'owner_action_bookings';
  static const ownerActionVenues = 'owner_action_venues';
  static const ownerDecisionConfirm = 'owner_decision_confirm';
  static const availabilityAddSlot = 'availability_add_slot';
  static const availabilitySlotLabel = 'availability_slot_label';
  static const availabilitySlotStart = 'availability_slot_start';
  static const availabilitySlotEnd = 'availability_slot_end';
  static const availabilitySlotPrice = 'availability_slot_price';
  static const availabilitySlotSave = 'availability_slot_save';

  // Admin.
  static const adminDashboard = 'admin_dashboard';

  /// Bottom-navigation destination, e.g. `nav_home`, `nav_search`.
  static String nav(String destinationId) => 'nav_$destinationId';

  /// A venue listing card, keyed by the venue's stable backend id.
  static String venueCard(String venueId) => 'venue_card_$venueId';

  /// A bookable time slot, keyed by the slot's stable backend id.
  static String slot(String slotId) => 'slot_$slotId';

  /// A booking-history card, keyed by the booking id.
  static String bookingCard(String bookingId) => 'booking_card_$bookingId';

  /// The cancel action on a booking-history card.
  static String bookingCancel(String bookingId) => 'booking_cancel_$bookingId';

  /// The refund action on a booking-history card.
  static String bookingRefund(String bookingId) => 'booking_refund_$bookingId';

  /// The pay action on a booking-history card.
  static String bookingPay(String bookingId) => 'booking_pay_$bookingId';

  /// A booking's lifecycle status badge. The backend status value is part of
  /// the id (e.g. `booking_status_b1_pending_owner_approval`), so suites
  /// assert state without reading localized text.
  static String bookingStatus(String bookingId, String dbStatus) =>
      'booking_status_${bookingId}_$dbStatus';

  /// A booking card on the owner's bookings screen.
  static String ownerBookingCard(String bookingId) =>
      'owner_booking_card_$bookingId';

  /// Owner approve / reject actions for a booking awaiting sign-off.
  static String ownerBookingApprove(String bookingId) =>
      'owner_booking_approve_$bookingId';
  static String ownerBookingReject(String bookingId) =>
      'owner_booking_reject_$bookingId';

  /// A listing card on the owner's venues screen, and its actions.
  static String ownerVenueCard(String venueId) => 'owner_venue_card_$venueId';
  static String ownerVenuePublish(String venueId) =>
      'owner_venue_publish_$venueId';
  static String ownerVenueAvailability(String venueId) =>
      'owner_venue_availability_$venueId';

  /// Publication state of an owner listing (`published` / `unpublished`).
  static String ownerVenueState(String venueId, String state) =>
      'owner_venue_state_${venueId}_$state';

  /// An owner time slot row (by label) and its active toggle state.
  static String availabilitySlot(String label) => 'availability_slot_$label';
  static String availabilitySlotState(String label, String state) =>
      'availability_slot_state_${label}_$state';
}

/// Attaches a stable end-to-end [id] to [child] without changing it.
///
/// Creates a dedicated semantics node (so web exposes the identifier on its
/// own element) and keys it with `ValueKey<String>(id)` for widget finders.
class TestId extends StatelessWidget {
  const TestId(this.id, {super.key, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey<String>(id),
      container: true,
      identifier: id,
      child: child,
    );
  }
}
