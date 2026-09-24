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

  // Checkout.
  static const checkoutSummary = 'checkout_summary';

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
