import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/core/widgets/test_id.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner_bookings/domain/owner_booking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../robots/auth_robot.dart';
import '../robots/booking_robot.dart';
import '../robots/history_robot.dart';
import '../robots/navigation_robot.dart';
import '../robots/owner_robot.dart';
import '../robots/payment_robot.dart';
import '../robots/search_robot.dart';
import '../robots/venue_robot.dart';
import '../support/e2e_env.dart';
import '../support/e2e_fixtures.dart';
import '../support/e2e_harness.dart';
import '../support/mock_backend.dart';

/// Phase 2 mocked business flows: owner, lifecycle, payment, cancellation,
/// authorization boundaries, duplicate submission and failure recovery.
/// Deterministic, no Supabase, no Razorpay, no network.
void registerMockBusinessFlows() {
  _authBoundaryFlows();
  _ownerFlows();
  _lifecycleAndPaymentFlows();
  _cancellationFlows();
  _resilienceFlows();
}

String _status(BookingStatus status) => status.dbValue;

// ---------------------------------------------------------------------------
// Authentication and role boundaries
// ---------------------------------------------------------------------------
void _authBoundaryFlows() {
  e2eFlow(
    'invalid password shows an error and stays signed out',
    {E2eTags.auth, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.invalidLogin);
      final auth = AuthRobot(tester);
      await auth.signInWithPassword(
        E2eFixtures.customer.email,
        E2eFixtures.mockPassword,
      );
      await auth.expectSignInError();
      auth.expectShown(E2eIds.loginSubmit);
      auth.expectNotShown(E2eIds.nav(ShellTab.home));
      expect(backend.auth.currentUser, isNull);
      expect(backend.auth.signInCount, 1);
    },
  );

  e2eFlow(
    'invalid OTP shows an error and does not sign in',
    {E2eTags.auth, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.invalidOtp);
      final auth = AuthRobot(tester);
      await auth.requestEmailOtp(E2eFixtures.customer.email);
      await auth.submitOtp(E2eFixtures.mockOtp);
      await auth.expectSignInError();
      auth.expectNotShown(E2eIds.nav(ShellTab.home));
      expect(backend.auth.currentUser, isNull);
      expect(backend.auth.verifyCount, 1);
    },
  );

  e2eFlow(
    'signed-out deep link to the owner area requires sign-in',
    {E2eTags.auth, E2eTags.owner, E2eTags.negative},
    (tester) async {
      await pumpMockApp(
        tester,
        MockScenario.signedOut,
        initialLocation: AppRoutes.ownerBookings,
      );
      await AuthRobot(tester).expectSignInScreen();
      expect(currentLocation(tester), AppRoutes.login);
      AuthRobot(tester).expectNotShown(E2eIds.ownerDashboard);
    },
  );

  e2eFlow(
    'customer is redirected away from owner and admin areas',
    {E2eTags.auth, E2eTags.owner, E2eTags.admin, E2eTags.negative},
    (tester) async {
      for (final protected in [AppRoutes.ownerDashboard, '/admin']) {
        final backend = await pumpMockApp(
          tester,
          MockScenario.signedIn,
          initialLocation: protected,
        );
        final auth = AuthRobot(tester);
        await auth.reveal(E2eIds.logout);
        expect(currentLocation(tester), AppRoutes.profile, reason: protected);
        auth.expectNotShown(E2eIds.ownerDashboard);
        auth.expectNotShown(E2eIds.adminDashboard);
        // The profile offers no role entry points to a customer.
        auth.expectNotShown(E2eIds.profileOwnerDashboard);
        auth.expectNotShown(E2eIds.profileAdminDashboard);
        expect(backend.auth.currentUser?.role, UserRole.customer);
      }
    },
  );

  e2eFlow(
    'owner signs in and reaches the owner dashboard',
    {E2eTags.critical, E2eTags.auth, E2eTags.owner},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.signedOut);
      await AuthRobot(
        tester,
      ).signInWithPassword(E2eFixtures.owner.email, E2eFixtures.mockPassword);
      final nav = NavigationRobot(tester);
      await nav.expectSignedInShell();
      await nav.open(ShellTab.profile);
      await nav.reveal(E2eIds.profileOwnerDashboard);
      nav.expectNotShown(E2eIds.profileAdminDashboard);
      await nav.tap(E2eIds.profileOwnerDashboard);
      await OwnerRobot(tester).expectDashboard();
      expect(backend.auth.currentUser?.role, UserRole.venueOwner);
    },
  );

  e2eFlow(
    'owner is redirected away from the admin area',
    {E2eTags.auth, E2eTags.owner, E2eTags.admin, E2eTags.negative},
    (tester) async {
      await pumpMockApp(
        tester,
        MockScenario.ownerSignedIn,
        initialLocation: AppRoutes.adminDashboard,
      );
      final auth = AuthRobot(tester);
      await auth.reveal(E2eIds.logout);
      expect(currentLocation(tester), AppRoutes.profile);
      auth.expectNotShown(E2eIds.adminDashboard);
      auth.expectNotShown(E2eIds.profileAdminDashboard);
    },
  );

  e2eFlow(
    'admin reaches the admin dashboard from profile',
    {E2eTags.auth, E2eTags.admin},
    (tester) async {
      await pumpMockApp(tester, MockScenario.adminSignedIn);
      final nav = NavigationRobot(tester);
      await nav.open(ShellTab.profile);
      await nav.reveal(E2eIds.profileAdminDashboard);
      await nav.tap(E2eIds.profileAdminDashboard);
      await nav.waitFor(E2eIds.adminDashboard);
      // The dashboard is pushed over the profile tab (go_router `push` keeps
      // the router location at /profile), so assert what is on screen.
      nav.expectNotShown(E2eIds.logout);
    },
  );
}

// ---------------------------------------------------------------------------
// Owner: bookings decisions, listings, availability
// ---------------------------------------------------------------------------
void _ownerFlows() {
  e2eFlow(
    'owner approves a booking awaiting sign-off',
    {E2eTags.critical, E2eTags.owner, E2eTags.booking},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.ownerSignedIn,
        initialLocation: AppRoutes.ownerDashboard,
      );
      const id = E2eFixtures.approvalBookingId;
      final owner = OwnerRobot(tester);
      await owner.expectDashboard();
      await owner.openBookings();
      await owner.expectBooking(
        id,
        _status(BookingStatus.pendingOwnerApproval),
      );
      await owner.approve(id);
      await owner.expectBooking(id, _status(BookingStatus.confirmed));
      owner.expectNotShown(E2eIds.ownerBookingApprove(id));
      owner.expectNotShown(E2eIds.ownerBookingReject(id));
      expect(backend.ownerBookings.lastDecidedBookingId, id);
      expect(backend.ownerBookings.lastDecision, OwnerBookingDecision.approve);
      expect(backend.statusOf(id), BookingStatus.confirmed);
    },
  );

  e2eFlow(
    'owner rejects a booking awaiting sign-off',
    {E2eTags.owner, E2eTags.booking},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.ownerSignedIn,
        initialLocation: AppRoutes.ownerDashboard,
      );
      const id = E2eFixtures.approvalBookingId;
      final owner = OwnerRobot(tester);
      await owner.expectDashboard();
      await owner.openBookings();
      await owner.reject(id);
      await owner.expectBooking(id, _status(BookingStatus.rejected));
      owner.expectNotShown(E2eIds.ownerBookingApprove(id));
      expect(backend.ownerBookings.lastDecision, OwnerBookingDecision.reject);
      expect(backend.statusOf(id), BookingStatus.rejected);
      // The already-confirmed booking is untouched by the decision.
      expect(
        backend.statusOf(E2eFixtures.confirmedBookingId),
        BookingStatus.confirmed,
      );
    },
  );

  e2eFlow('owner unpublishes and republishes a listing', {E2eTags.owner}, (
    tester,
  ) async {
    final backend = await pumpMockApp(
      tester,
      MockScenario.ownerSignedIn,
      initialLocation: AppRoutes.ownerDashboard,
    );
    const venue = E2eFixtures.venueId;
    final owner = OwnerRobot(tester);
    await owner.expectDashboard();
    await owner.openVenues();
    await owner.expectVenueState(venue, 'published');
    await owner.togglePublished(venue);
    await owner.expectVenueState(venue, 'unpublished');
    expect(backend.ownerVenues.venues.single.isActive, isFalse);
    await owner.togglePublished(venue);
    await owner.expectVenueState(venue, 'published');
    expect(backend.ownerVenues.venues.single.isActive, isTrue);
  });

  e2eFlow('owner adds a time slot and deactivates it', {E2eTags.owner}, (
    tester,
  ) async {
    final backend = await pumpMockApp(
      tester,
      MockScenario.ownerSignedIn,
      initialLocation: AppRoutes.ownerDashboard,
    );
    const label = E2eFixtures.newSlotLabel;
    final owner = OwnerRobot(tester);
    await owner.expectDashboard();
    await owner.openVenues();
    await owner.openAvailability(E2eFixtures.venueId);
    await owner.addSlot(
      label: label,
      start: '10:00',
      end: '12:00',
      price: '5000',
    );
    await owner.expectSlot(label, 'active');
    final saved =
        backend.ownerAvailability.slotsByVenue[E2eFixtures.venueId]!.single;
    expect(saved.label, label);
    expect(saved.startTime, '10:00:00');
    expect(saved.endTime, '12:00:00');
    expect(saved.priceAmount, 5000);
    expect(saved.isActive, isTrue);

    await owner.toggleSlot(label);
    await owner.expectSlot(label, 'inactive');
    expect(
      backend
          .ownerAvailability
          .slotsByVenue[E2eFixtures.venueId]!
          .single
          .isActive,
      isFalse,
    );
  });

  e2eFlow(
    'owner cannot save a time slot that ends before it starts',
    {E2eTags.owner, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.ownerSignedIn,
        initialLocation: AppRoutes.ownerDashboard,
      );
      final owner = OwnerRobot(tester);
      await owner.expectDashboard();
      await owner.openVenues();
      await owner.openAvailability(E2eFixtures.venueId);
      await owner.addSlot(
        label: E2eFixtures.newSlotLabel,
        start: '12:00',
        end: '10:00',
        price: '5000',
      );
      // Validation keeps the dialog open and nothing reaches the backend.
      owner.expectShown(E2eIds.availabilitySlotSave);
      owner.expectNotShown(E2eIds.availabilitySlot(E2eFixtures.newSlotLabel));
      expect(backend.ownerAvailability.saveSlotCalls, 0);
    },
  );
}

// ---------------------------------------------------------------------------
// Booking lifecycle and payment
// ---------------------------------------------------------------------------
void _lifecycleAndPaymentFlows() {
  e2eFlow(
    'lifecycle: hold, pay at venue, owner approves, customer sees confirmed',
    {E2eTags.critical, E2eTags.booking, E2eTags.payment, E2eTags.owner},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.signedIn);
      final nav = NavigationRobot(tester);
      final auth = AuthRobot(tester);
      final history = HistoryRobot(tester);

      // Customer: find the venue, take a hold, choose pay at venue.
      await nav.open(ShellTab.search);
      await SearchRobot(tester).search(E2eFixtures.venueSearchQuery);
      await SearchRobot(tester).openVenue(E2eFixtures.venueId);
      await VenueRobot(tester).startBooking();
      final booking = BookingRobot(tester);
      await booking.enterEventType(E2eFixtures.eventType);
      await booking.selectSlot(E2eFixtures.availableSlotId);
      await booking.confirm();
      final payment = PaymentRobot(tester);
      await payment.expectCheckout();
      final id = backend.booking.createdBooking!.id;
      expect(backend.statusOf(id), BookingStatus.pending);

      await payment.choosePayAtVenue();
      await payment.pay();
      await payment.expectPending();
      payment.expectNotShown(E2eIds.bookingSuccess);
      expect(backend.payments.lastPayAtVenueBookingId, id);
      expect(backend.statusOf(id), BookingStatus.pendingOwnerApproval);
      // Pay at venue never creates an online order or opens checkout.
      expect(backend.payments.createOrderCalls, 0);
      expect(backend.checkout.openCalls, 0);

      // History shows the booking as awaiting the owner.
      await payment.done();
      await nav.open(ShellTab.bookings);
      await history.expectStatus(
        id,
        _status(BookingStatus.pendingOwnerApproval),
      );

      // Owner signs in and approves it.
      await nav.open(ShellTab.profile);
      await auth.signOut();
      await auth.expectSignInScreen();
      await auth.signInWithPassword(
        E2eFixtures.owner.email,
        E2eFixtures.mockPassword,
      );
      await nav.expectSignedInShell();
      await nav.open(ShellTab.profile);
      await nav.reveal(E2eIds.profileOwnerDashboard);
      await nav.tap(E2eIds.profileOwnerDashboard);
      final owner = OwnerRobot(tester);
      await owner.expectDashboard();
      await owner.openBookings();
      await owner.expectBooking(
        id,
        _status(BookingStatus.pendingOwnerApproval),
      );
      await owner.approve(id);
      await owner.expectBooking(id, _status(BookingStatus.confirmed));
      expect(backend.statusOf(id), BookingStatus.confirmed);

      // Customer signs back in and sees the confirmation in history.
      await owner.back();
      await owner.back();
      await nav.open(ShellTab.profile);
      await auth.signOut();
      await auth.signInWithPassword(
        E2eFixtures.customer.email,
        E2eFixtures.mockPassword,
      );
      await nav.expectSignedInShell();
      await nav.open(ShellTab.bookings);
      await history.expectStatus(id, _status(BookingStatus.confirmed));
    },
  );

  e2eFlow(
    'online payment is captured and awaits owner approval',
    {E2eTags.critical, E2eTags.payment, E2eTags.booking},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.withBookings);
      const id = E2eFixtures.seededBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      await HistoryRobot(tester).pay(id);
      final payment = PaymentRobot(tester);
      await payment.expectCheckout();
      await payment.pay();
      // The pay action is single-shot: it is gone once checkout starts.
      expect(await payment.tapIfShown(E2eIds.paymentPay), isFalse);
      await payment.expectPending();
      payment.expectNotShown(E2eIds.bookingSuccess);
      expect(backend.payments.createOrderCalls, 1);
      expect(backend.payments.lastOrderBookingId, id);
      expect(backend.checkout.openCalls, 1);
      expect(backend.checkout.lastOrderId, 'order_1');
      expect(backend.statusOf(id), BookingStatus.pendingOwnerApproval);
    },
  );

  e2eFlow(
    'payment approved while verifying shows the booking confirmation',
    {E2eTags.payment, E2eTags.booking},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.payApprovedWhileVerifying,
      );
      const id = E2eFixtures.seededBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      await HistoryRobot(tester).pay(id);
      final payment = PaymentRobot(tester);
      await payment.pay();
      await payment.expectSuccess();
      expect(backend.statusOf(id), BookingStatus.confirmed);
      expect(backend.payments.createOrderCalls, 1);
    },
  );

  e2eFlow(
    'failed checkout shows an error and never confirms',
    {E2eTags.payment, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.payFails);
      const id = E2eFixtures.seededBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      await HistoryRobot(tester).pay(id);
      final payment = PaymentRobot(tester);
      await payment.pay();
      await payment.expectError();
      payment.expectNotShown(E2eIds.paymentVerifying);
      payment.expectNotShown(E2eIds.bookingSuccess);
      expect(backend.checkout.openCalls, 1);
      expect(backend.payments.statusCalls, 0);
      expect(backend.statusOf(id), BookingStatus.pending);
    },
  );

  e2eFlow(
    'cancelled checkout can be retried',
    {E2eTags.payment, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.payCancelledThenPaid,
      );
      const id = E2eFixtures.seededBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      await HistoryRobot(tester).pay(id);
      final payment = PaymentRobot(tester);
      await payment.pay();
      await payment.expectMessage();
      expect(backend.statusOf(id), BookingStatus.pending);
      await payment.pay();
      await payment.expectPending();
      expect(backend.payments.createOrderCalls, 2);
      expect(backend.checkout.openCalls, 2);
      expect(backend.statusOf(id), BookingStatus.pendingOwnerApproval);
    },
  );

  e2eFlow(
    'order creation failure is reported and a retry succeeds',
    {E2eTags.payment, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.orderFailsOnce);
      const id = E2eFixtures.seededBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      final history = HistoryRobot(tester);
      await history.pay(id);
      final payment = PaymentRobot(tester);
      await payment.pay();
      await payment.expectError();
      // The provider checkout is never opened without a server order.
      expect(backend.checkout.openCalls, 0);
      await payment.done();
      await history.pay(id);
      await payment.pay();
      await payment.expectPending();
      expect(backend.payments.createOrderCalls, 2);
      expect(backend.checkout.openCalls, 1);
    },
  );

  e2eFlow(
    'an expired hold blocks payment',
    {E2eTags.payment, E2eTags.booking, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.staleHold);
      const id = E2eFixtures.staleHoldBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      await HistoryRobot(tester).pay(id);
      final payment = PaymentRobot(tester);
      await payment.expectCheckout();
      await payment.expectHoldExpired();
      await payment.pay();
      await payment.choosePayAtVenue();
      await payment.pay();
      payment.expectNotShown(E2eIds.paymentVerifying);
      payment.expectNotShown(E2eIds.paymentPending);
      expect(backend.payments.createOrderCalls, 0);
      expect(backend.payments.payAtVenueCalls, 0);
      expect(backend.checkout.openCalls, 0);
      expect(backend.statusOf(id), BookingStatus.pending);
    },
  );
}

// ---------------------------------------------------------------------------
// Cancellation and refund
// ---------------------------------------------------------------------------
void _cancellationFlows() {
  e2eFlow(
    'customer cancels a pending booking',
    {E2eTags.critical, E2eTags.booking},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.withBookings);
      const id = E2eFixtures.seededBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      final history = HistoryRobot(tester);
      await history.expectStatus(id, _status(BookingStatus.pending));
      await history.cancel(id);
      await history.waitForAbsence(E2eIds.bookingCard(id));
      await history.openCancelled();
      await history.expectStatus(id, _status(BookingStatus.cancelled));
      history.expectNotShown(E2eIds.bookingCancel(id));
      history.expectNotShown(E2eIds.bookingPay(id));
      expect(backend.booking.cancelCalls, 1);
      expect(backend.statusOf(id), BookingStatus.cancelled);
    },
  );

  e2eFlow(
    'a cancellation rejected by the server keeps the booking',
    {E2eTags.booking, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.cancelFails);
      const id = E2eFixtures.seededBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      final history = HistoryRobot(tester);
      await history.cancel(id);
      await history.expectStatus(id, _status(BookingStatus.pending));
      history.expectShown(E2eIds.bookingCancel(id));
      expect(backend.booking.cancelCalls, 1);
      expect(backend.statusOf(id), BookingStatus.pending);
    },
  );

  e2eFlow(
    'customer requests a refund for a confirmed booking',
    {E2eTags.booking, E2eTags.payment},
    (tester) async {
      final backend = await pumpMockApp(tester, MockScenario.confirmedBooking);
      const id = E2eFixtures.confirmedBookingId;
      await NavigationRobot(tester).open(ShellTab.bookings);
      final history = HistoryRobot(tester);
      await history.expectStatus(id, _status(BookingStatus.confirmed));
      history.expectNotShown(E2eIds.bookingCancel(id));
      await history.requestRefund(id);
      expect(backend.payments.refundCalls, 1);
      expect(backend.payments.lastRefundBookingId, id);
      expect(
        backend.payments.lastRefundAmount,
        E2eFixtures.seededBooking(id, BookingStatus.confirmed).totalAmount,
      );
      // A refund request is not a refund: the booking is not shown as
      // refunded until the server says so.
      await history.expectStatus(id, _status(BookingStatus.confirmed));
      expect(backend.statusOf(id), BookingStatus.confirmed);
    },
  );
}

// ---------------------------------------------------------------------------
// Failures, retries and duplicate submission
// ---------------------------------------------------------------------------
void _resilienceFlows() {
  e2eFlow(
    'slot availability failure recovers on retry',
    {E2eTags.booking, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.flakyAvailability,
        initialLocation: '/v1/venues/${E2eFixtures.venueId}',
      );
      await VenueRobot(tester).startBooking();
      final booking = BookingRobot(tester);
      await booking.tap(E2eIds.errorRetry);
      await booking.expectSlotPicker();
      booking.expectShown(E2eIds.slot(E2eFixtures.availableSlotId));
      expect(backend.booking.availabilityCalls, 2);
    },
  );

  e2eFlow(
    'persistent availability failure keeps offering retry',
    {E2eTags.booking, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.networkFailure,
        initialLocation: '/v1/venues/${E2eFixtures.venueId}',
      );
      await VenueRobot(tester).startBooking();
      final booking = BookingRobot(tester);
      await booking.tap(E2eIds.errorRetry);
      await booking.waitFor(E2eIds.errorRetry);
      booking.expectNotShown(E2eIds.slotPicker);
      booking.expectNotShown(E2eIds.bookingConfirm);
      expect(backend.booking.availabilityCalls, greaterThanOrEqualTo(2));
      expect(backend.booking.acquireCalls, 0);
    },
  );

  e2eFlow(
    'a slot taken by someone else is reported and nothing is booked',
    {E2eTags.booking, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.slotTaken,
        initialLocation: '/v1/venues/${E2eFixtures.venueId}',
      );
      await VenueRobot(tester).startBooking();
      final booking = BookingRobot(tester);
      await booking.enterEventType(E2eFixtures.eventType);
      await booking.selectSlot(E2eFixtures.availableSlotId);
      await booking.confirm();
      booking.expectShown(E2eIds.slotPicker);
      booking.expectNotShown(E2eIds.checkoutSummary);
      expect(backend.booking.acquireCalls, 1);
      expect(backend.booking.createCalls, 0);
      expect(backend.store, isEmpty);
    },
  );

  e2eFlow(
    'an unavailable slot cannot be booked',
    {E2eTags.booking, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.signedIn,
        initialLocation: '/v1/venues/${E2eFixtures.venueId}',
      );
      await VenueRobot(tester).startBooking();
      final booking = BookingRobot(tester);
      await booking.expectSlotPicker();
      await booking.selectSlot(E2eFixtures.unavailableSlotId);
      booking.expectNotShown(E2eIds.bookingConfirm);
      expect(backend.booking.acquireCalls, 0);
    },
  );

  e2eFlow(
    'a second confirm while the hold is in flight takes one hold',
    {E2eTags.booking, E2eTags.negative},
    (tester) async {
      final backend = await pumpMockApp(
        tester,
        MockScenario.slowHold,
        initialLocation: '/v1/venues/${E2eFixtures.venueId}',
      );
      await VenueRobot(tester).startBooking();
      final booking = BookingRobot(tester);
      await booking.enterEventType(E2eFixtures.eventType);
      await booking.selectSlot(E2eFixtures.availableSlotId);
      await booking.tapWithoutSettling(E2eIds.bookingConfirm);
      // Standard mode asks for confirmation; quick mode goes straight on.
      if (booking.byId(E2eIds.bookingConfirmDialog).evaluate().isNotEmpty) {
        await booking.tapWithoutSettling(E2eIds.bookingConfirmDialog);
      }
      // The hold request is now in flight (1.5 s): press confirm again.
      expect(backend.booking.acquireCalls, 1);
      await booking.tapWithoutSettling(E2eIds.bookingConfirm);
      booking.expectNotShown(E2eIds.bookingConfirmDialog);
      await PaymentRobot(tester).expectCheckout();
      expect(backend.booking.acquireCalls, 1);
      expect(backend.booking.createCalls, 1);
      expect(backend.store, hasLength(1));
    },
  );
}

/// The router's current location, e.g. `/profile`.
String currentLocation(WidgetTester tester) {
  final context = tester.element(find.byType(Navigator).first);
  return GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
}
