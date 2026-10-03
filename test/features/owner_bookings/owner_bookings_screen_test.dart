import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner_bookings/domain/owner_booking_repository.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/owner_booking_providers.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/screens/owner_bookings_screen.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/widgets/reject_reason_dialog.dart';
import 'package:bookmyspace/features/owner_venues/presentation/providers/owner_venue_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository_release.dart';
import '../owner_venues/mock_owner_venue_repository.dart';
import 'mock_owner_booking_repository.dart';

Widget _app(
  MockOwnerBookingRepository ownerBookingRepo,
  MockOwnerVenueRepository ownerVenueRepo, {
  String initialLocation = AppRoutes.ownerBookingsManager,
}) {
  return ProviderScope(
    overrides: [
      ownerBookingRepositoryProvider.overrideWithValue(ownerBookingRepo),
      ownerVenueRepositoryProvider.overrideWithValue(ownerVenueRepo),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(
            id: 'u1',
            email: 'owner@b.com',
            role: UserRole.venueOwner,
          ),
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: initialLocation,
        currentUser: const AuthUser(
          id: 'u1',
          email: 'owner@b.com',
          role: UserRole.venueOwner,
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Booking _booking({
  String id = 'b1',
  BookingStatus status = BookingStatus.pending,
  bool offline = true,
  String paymentMethod = '',
  String venueName = 'Sunrise Function Hall',
  String bookingRef = 'BMS-1A2B3C',
}) {
  return Booking(
    id: id,
    bookingRef: bookingRef,
    venueId: 'v1',
    slotId: 's1',
    bookDate: DateTime(2026, 9, 1),
    startTime: '09:00:00',
    endTime: '13:00:00',
    status: status,
    amount: 35000,
    taxAmount: 6300,
    totalAmount: 41300,
    venueName: venueName,
    slotLabel: 'Morning',
    customerName: offline ? 'Ravi Kumar' : '',
    customerPhone: offline ? '9876543210' : '',
    isOffline: offline,
    paymentMethod: paymentMethod,
  );
}

void main() {
  testWidgets('lists bookings and shows status actions for pending bookings', (
    tester,
  ) async {
    final bookingRepo = MockOwnerBookingRepository(
      bookings: [
        _booking(),
        _booking(id: 'b2', status: BookingStatus.confirmed),
      ],
    );
    final ownerVenueRepo = MockOwnerVenueRepository()
      ..venues.add(
        const Venue(
          id: 'v1',
          name: 'Sunrise Function Hall',
          city: 'Hyderabad',
          state: 'Telangana',
          latitude: 17.38,
          longitude: 78.48,
          capacity: 500,
          pricingBaseAmount: 35000,
          category: VenueCategory(
            id: 'cat-1',
            slug: 'function_hall',
            name: 'Function Hall',
          ),
        ),
      );

    await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Function Hall'), findsNWidgets(2));
    expect(find.text('Ravi Kumar'), findsNWidgets(2));
    expect(find.text('BMS-1A2B3C'), findsNWidgets(2));

    // Pending booking offers Confirm action; the confirmed booking shows a status badge.
    expect(find.text('Confirmed'), findsNWidgets(2));
    expect(find.text('Cancel Booking'), findsNWidgets(2));

    // The FAB is visible when the owner has venues.
    expect(find.text('New offline booking'), findsOneWidget);
  });

  testWidgets('confirming a pending booking applies the transition', (
    tester,
  ) async {
    final bookingRepo = MockOwnerBookingRepository(bookings: [_booking()]);
    final ownerVenueRepo = MockOwnerVenueRepository();

    await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmed').first);
    await tester.pumpAndSettle();

    // Confirmation dialog: title + button both show "Confirmed".
    expect(find.text('Confirmed'), findsNWidgets(3));
    await tester.tap(find.text('Confirmed').last);
    await tester.pumpAndSettle();

    expect(bookingRepo.lastUpdatedBookingId, 'b1');
    expect(bookingRepo.lastAction, OwnerBookingAction.confirm);
    // The booking is now confirmed, so Confirm disappears and Complete appears.
    expect(find.text('Mark completed'), findsOneWidget);
  });

  testWidgets(
    'pending_owner_approval booking shows Approve/Reject and approving confirms it',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [_booking(status: BookingStatus.pendingOwnerApproval)],
      );
      final ownerVenueRepo = MockOwnerVenueRepository();

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      // Confirm/Cancel actions are not offered while awaiting owner approval.
      expect(find.text('Confirmed'), findsNothing);
      expect(find.text('Cancel Booking'), findsNothing);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Confirmation dialog title + button both read "Approve".
      expect(find.text('Approve'), findsNWidgets(3));
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(bookingRepo.lastDecidedBookingId, 'b1');
      expect(bookingRepo.lastDecision, OwnerBookingDecision.approve);
      expect(find.text('Booking approved'), findsOneWidget);
      // The booking is now confirmed, so Approve/Reject disappear.
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    },
  );

  testWidgets(
    'rejecting a pending_owner_approval booking with a refund shows the refund message',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [_booking(status: BookingStatus.pendingOwnerApproval)],
      )..decideBookingRefundStatus = 'initiated';
      final ownerVenueRepo = MockOwnerVenueRepository();

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(RejectReasonDialog.presetKey(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RejectReasonDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(bookingRepo.lastDecidedBookingId, 'b1');
      expect(bookingRepo.lastDecision, OwnerBookingDecision.reject);
      expect(bookingRepo.lastDecisionReason, kBookingRejectionPresets[1]);
      expect(find.text('Booking rejected. Refund requested.'), findsOneWidget);
    },
  );

  testWidgets(
    'rejecting an unpaid pending_owner_approval booking shows the plain rejected message',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [_booking(status: BookingStatus.pendingOwnerApproval)],
      );
      final ownerVenueRepo = MockOwnerVenueRepository();

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(RejectReasonDialog.reasonFieldKey),
        '  Hall closed for repairs  ',
      );
      await tester.tap(find.byKey(RejectReasonDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(bookingRepo.lastDecision, OwnerBookingDecision.reject);
      expect(bookingRepo.lastDecisionReason, 'Hall closed for repairs');
      expect(find.text('Booking rejected'), findsOneWidget);
    },
  );

  testWidgets('reject requires a reason and can be cancelled', (tester) async {
    final bookingRepo = MockOwnerBookingRepository(
      bookings: [_booking(status: BookingStatus.awaitingOwnerApproval)],
    );
    final ownerVenueRepo = MockOwnerVenueRepository();

    await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
    await tester.pumpAndSettle();

    // awaiting_owner_approval requests get the decision actions too.
    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(RejectReasonDialog.confirmKey));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a reason'), findsOneWidget);
    expect(bookingRepo.lastDecision, isNull);

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.byType(RejectReasonDialog), findsNothing);
    expect(bookingRepo.lastDecision, isNull);
  });

  testWidgets('a failed decision shows the error and leaves status unchanged', (
    tester,
  ) async {
    final bookingRepo = MockOwnerBookingRepository(
      bookings: [_booking(status: BookingStatus.pendingOwnerApproval)],
    )..failDecideBooking = true;
    final ownerVenueRepo = MockOwnerVenueRepository();

    await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve').last);
    await tester.pumpAndSettle();

    expect(find.text('Exception: decide failed'), findsOneWidget);
    // Buttons remain because the status never changed.
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('shows empty state when the owner has no venues', (tester) async {
    final bookingRepo = MockOwnerBookingRepository();
    final ownerVenueRepo = MockOwnerVenueRepository();

    await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
    await tester.pumpAndSettle();

    expect(find.text('No bookings for your venues yet'), findsOneWidget);
    expect(
      find.text('You need at least one venue before managing bookings.'),
      findsOneWidget,
    );
    expect(find.text('New offline booking'), findsNothing);
  });

  testWidgets(
    'shows a Pay at venue chip for a customer booking that chose it, and '
    'no chip for one that did not',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [
          _booking(
            id: 'b1',
            offline: false,
            paymentMethod: 'pay_at_venue',
            status: BookingStatus.pendingOwnerApproval,
          ),
          _booking(id: 'b2', offline: false, status: BookingStatus.confirmed),
        ],
      );
      final ownerVenueRepo = MockOwnerVenueRepository()
        ..venues.add(
          const Venue(
            id: 'v1',
            name: 'Sunrise Function Hall',
            city: 'Hyderabad',
            state: 'Telangana',
            latitude: 17.38,
            longitude: 78.48,
            capacity: 500,
            pricingBaseAmount: 35000,
            category: VenueCategory(
              id: 'cat-1',
              slug: 'function_hall',
              name: 'Function Hall',
            ),
          ),
        );

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      // Only the booking that actually chose pay-at-venue shows the chip.
      expect(find.text('Pay at venue'), findsOneWidget);
    },
  );

  // Request-to-book (`awaiting_owner_approval`) works the same for every
  // booking category: the owner may approve or decline, approval moves the
  // request to waiting-for-payment (`pending`) and never confirms it, and a
  // request someone else (an administrator) already decided is reported as
  // processed and refreshed.
  group('owner decisions on booking requests, every category', () {
    const categories = <String, String>{
      'Function Hall': 'Sunrise Function Hall',
      'Hotel / Stay': 'Lake View Hotel',
      'PG': 'Green Nest PG',
      'Institute': 'Bright Future Institute',
      'Sports ground': 'City Turf Arena',
      'Meeting room': 'Hub Meeting Room',
      'Coworking': 'Desk Coworking Space',
    };

    MockOwnerBookingRepository repoFor(String venueName) =>
        MockOwnerBookingRepository(
          bookings: [
            _booking(
              status: BookingStatus.awaitingOwnerApproval,
              venueName: venueName,
            ),
          ],
        );

    for (final MapEntry(key: category, value: venueName)
        in categories.entries) {
      testWidgets('$category: owner approves -> waiting for payment', (
        tester,
      ) async {
        final repo = repoFor(venueName);
        await tester.pumpWidget(_app(repo, MockOwnerVenueRepository()));
        await tester.pumpAndSettle();
        expect(find.text(venueName), findsOneWidget);

        await tester.tap(find.text('Approve'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Approve').last);
        await tester.pumpAndSettle();

        expect(repo.lastDecision, OwnerBookingDecision.approve);
        expect(repo.bookingById('b1').status, BookingStatus.pending);
        expect(repo.bookingById('b1').status, isNot(BookingStatus.confirmed));
        expect(find.text('Booking approved'), findsOneWidget);
        expect(find.text('Approve'), findsNothing);
        expect(find.text('Reject'), findsNothing);
      });

      testWidgets('$category: owner declines with a reason', (tester) async {
        final repo = repoFor(venueName);
        await tester.pumpWidget(_app(repo, MockOwnerVenueRepository()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(RejectReasonDialog.reasonFieldKey),
          'Not available on this date',
        );
        await tester.tap(find.byKey(RejectReasonDialog.confirmKey));
        await tester.pumpAndSettle();

        expect(repo.lastDecision, OwnerBookingDecision.reject);
        expect(repo.lastDecisionReason, 'Not available on this date');
        expect(repo.bookingById('b1').status, BookingStatus.ownerRejected);
        expect(find.text('Booking rejected'), findsOneWidget);
        expect(find.text('Approve'), findsNothing);
      });
    }

    testWidgets(
      'admin approved first: owner Approve is reported as already processed '
      'and the list refreshes',
      (tester) async {
        final repo = repoFor('Lake View Hotel');
        await tester.pumpWidget(_app(repo, MockOwnerVenueRepository()));
        await tester.pumpAndSettle();
        expect(find.text('Approve'), findsOneWidget);

        // An administrator approves while the owner's list is open.
        repo.decideElsewhere('b1', BookingStatus.pending);

        await tester.tap(find.text('Approve'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Approve').last);
        await tester.pumpAndSettle();

        expect(
          find.text('This request has already been processed.'),
          findsOneWidget,
        );
        // Still waiting for payment: the stale tap did not confirm it.
        expect(repo.bookingById('b1').status, BookingStatus.pending);
        // Refreshed: the stale decision buttons are gone.
        expect(find.text('Approve'), findsNothing);
        expect(find.text('Reject'), findsNothing);
      },
    );

    testWidgets(
      'admin approved first: owner Reject is refused and the list refreshes',
      (tester) async {
        final repo = repoFor('Green Nest PG');
        await tester.pumpWidget(_app(repo, MockOwnerVenueRepository()));
        await tester.pumpAndSettle();

        repo.decideElsewhere('b1', BookingStatus.pending);

        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(RejectReasonDialog.reasonFieldKey),
          'Too late',
        );
        await tester.tap(find.byKey(RejectReasonDialog.confirmKey));
        await tester.pumpAndSettle();

        expect(
          find.text('This booking cannot be moved to that status.'),
          findsOneWidget,
        );
        expect(repo.bookingById('b1').status, BookingStatus.pending);
        expect(find.text('Reject'), findsNothing);
      },
    );

    testWidgets('admin declined first: owner Approve is refused', (
      tester,
    ) async {
      final repo = repoFor('Bright Future Institute');
      await tester.pumpWidget(_app(repo, MockOwnerVenueRepository()));
      await tester.pumpAndSettle();

      repo.decideElsewhere('b1', BookingStatus.ownerRejected);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(
        find.text('This booking cannot be moved to that status.'),
        findsOneWidget,
      );
      expect(repo.bookingById('b1').status, BookingStatus.ownerRejected);
      expect(find.text('Approve'), findsNothing);
    });
  });
}
