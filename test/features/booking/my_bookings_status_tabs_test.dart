import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/widgets/test_id.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/my_bookings_screen.dart'
    hide MyBookingsScreen;
import 'package:bookmyspace/features/booking/presentation/screens/my_bookings_screen_v1.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository_release.dart';
import '../notifications/mock_notification_repository.dart';
import 'mock_booking_repository_release.dart';

/// Regression: every backend booking status is listed in exactly one
/// My Bookings tab (awaiting-approval, rejected, refunded and no-show
/// bookings used to match no tab and vanish from history).
void main() {
  setUp(FeatureRegistry.reset);
  tearDown(FeatureRegistry.reset);

  const expectedTab = {
    BookingStatus.held: E2eIds.bookingsTabUpcoming,
    BookingStatus.pending: E2eIds.bookingsTabUpcoming,
    BookingStatus.pendingOwnerApproval: E2eIds.bookingsTabUpcoming,
    BookingStatus.confirmed: E2eIds.bookingsTabUpcoming,
    BookingStatus.completed: E2eIds.bookingsTabCompleted,
    BookingStatus.noShow: E2eIds.bookingsTabCompleted,
    BookingStatus.cancelled: E2eIds.bookingsTabCancelled,
    BookingStatus.rejected: E2eIds.bookingsTabCancelled,
    BookingStatus.refunded: E2eIds.bookingsTabCancelled,
  };

  test('every booking status is assigned a tab', () {
    expect(expectedTab.keys.toSet(), BookingStatus.values.toSet());
  });

  testWidgets('each status appears in exactly one tab', (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bookings = [
      for (final status in BookingStatus.values)
        MockBookingRepository.sampleBooking(
          id: 'b-${status.dbValue}',
          status: status,
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          bookingRepositoryProvider.overrideWithValue(
            MockBookingRepository(bookings: bookings),
          ),
          notificationRepositoryProvider.overrideWithValue(
            MockNotificationRepository(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MyBookingsScreenV1(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder statusBadge(BookingStatus s) => find.byKey(
      ValueKey<String>(E2eIds.bookingStatus('b-${s.dbValue}', s.dbValue)),
    );

    final seen = <BookingStatus, List<String>>{};
    for (final tab in [
      E2eIds.bookingsTabUpcoming,
      E2eIds.bookingsTabCompleted,
      E2eIds.bookingsTabCancelled,
    ]) {
      await tester.tap(find.byKey(ValueKey<String>(tab)));
      await tester.pumpAndSettle();
      for (final status in BookingStatus.values) {
        if (statusBadge(status).evaluate().isNotEmpty) {
          seen.putIfAbsent(status, () => []).add(tab);
        }
      }
    }

    for (final status in BookingStatus.values) {
      expect(
        seen[status],
        [expectedTab[status]],
        reason: '${status.dbValue} should be listed in exactly one tab',
      );
    }
  });

  testWidgets('tabs remain available when the selected tab is empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          bookingRepositoryProvider.overrideWithValue(
            MockBookingRepository(
              bookings: [
                MockBookingRepository.sampleBooking(
                  id: 'upcoming-only',
                  status: BookingStatus.pending,
                ),
              ],
            ),
          ),
          notificationRepositoryProvider.overrideWithValue(
            MockNotificationRepository(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MyBookingsScreenV1(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cancelledTab = find.byKey(
      const ValueKey<String>(E2eIds.bookingsTabCancelled),
    );
    expect(cancelledTab, findsOneWidget);
    await tester.tap(cancelledTab);
    await tester.pumpAndSettle();

    expect(cancelledTab, findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>(E2eIds.bookingsTabUpcoming)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        ValueKey<String>(E2eIds.bookingStatus('upcoming-only', 'pending')),
      ),
      findsOneWidget,
    );
  });
}
