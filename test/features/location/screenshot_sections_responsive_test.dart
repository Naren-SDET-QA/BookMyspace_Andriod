import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:bookmyspace/features/location/presentation/location_providers.dart';
import 'package:bookmyspace/features/location/presentation/screens/india_place_discovery_screen.dart';
import 'package:bookmyspace/features/rewards/domain/rewards.dart';
import 'package:bookmyspace/features/rewards/presentation/rewards_providers.dart';
import 'package:bookmyspace/features/rewards/presentation/screens/referral_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../booking/mock_booking_repository.dart';

void main() {
  const viewports = <Size>[
    Size(320, 800),
    Size(390, 844),
    Size(768, 1024),
    Size(1280, 900),
  ];

  Future<void> pumpSized(
    WidgetTester tester,
    Size size,
    Widget child, {
    List<Override> overrides = const [],
    bool localize = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: localize
              ? const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ]
              : null,
          supportedLocales: localize
              ? AppLocalizations.supportedLocales
              : const [Locale('en')],
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('India Place Discovery lays out on every viewport', (tester) async {
    for (final size in viewports) {
      await pumpSized(
        tester,
        size,
        const IndiaPlaceDiscoveryScreen(),
        overrides: [
          locationChildrenProvider.overrideWith((ref, request) async => const []),
          listedVenueCitiesProvider.overrideWith(
            (ref) async => const ['Badvel', 'Ongole'],
          ),
        ],
      );
      expect(find.text('India Place Discovery'), findsOneWidget);
      expect(find.text('Discover Places in this Location'), findsOneWidget);
      expect(find.text('Badvel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Refer & Earn sections lay out on every viewport', (tester) async {
    for (final size in viewports) {
      await pumpSized(
        tester,
        size,
        const ReferralScreen(),
        overrides: [
          referralSummaryProvider.overrideWith(
            (ref) async => const ReferralSummary(
              code: 'BOOKMYSPACE500',
              items: [
                {'status': 'completed', 'created_at': '2026-08-10'},
                {'status': 'pending', 'created_at': '2026-08-14'},
              ],
            ),
          ),
          walletEntriesProvider.overrideWith(
            (ref) async => [
              WalletEntry(
                direction: 'credit',
                amount: 1250,
                description: 'reward',
                status: 'posted',
                createdAt: DateTime.utc(2026, 8, 1),
              ),
            ],
          ),
        ],
      );
      expect(find.text('Refer & Earn'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      // A later viewport reuses the binding's primary scroll offset, so
      // jump back to the hero before looking for above-the-fold copy.
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      expect(find.text('Give ₹500, Get ₹500!'), findsOneWidget);
      expect(find.text('BOOKMYSPACE500'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('How Referral Program Works'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('How Referral Program Works'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Send Direct Invitation'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Send Direct Invitation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('My Bookings tabs keep every status on a narrow phone', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 20);
    Booking booking(String id, BookingStatus status, String name) => Booking(
      id: id,
      bookingRef: id,
      venueId: 'v1',
      slotId: 's1',
      bookDate: now,
      startTime: '07:00',
      endTime: '08:00',
      status: status,
      amount: 650,
      taxAmount: 0,
      totalAmount: 650,
      venueName: name,
    );
    await pumpSized(
      tester,
      const Size(320, 900),
      const MyBookingsScreen(),
      localize: true,
      overrides: [
        bookingRepositoryProvider.overrideWithValue(
          MockBookingRepository(
            bookings: [
              booking('a', BookingStatus.confirmed, 'Velocity Pro Sports Arena'),
              booking('b', BookingStatus.completed, 'Finished Hall'),
              booking('c', BookingStatus.cancelled, 'Cancelled Lawn'),
              booking('d', BookingStatus.ownerRejected, 'Rejected Palace'),
            ],
          ),
        ),
      ],
    );

    expect(find.text('My Bookings & Payments'), findsOneWidget);
    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Velocity Pro Sports Arena'), findsOneWidget);
    expect(find.text('Finished Hall'), findsNothing);
    expect(find.text('Cancelled Lawn'), findsNothing);

    await tester.tap(find.byKey(const Key('booking-filter-completed')));
    await tester.pumpAndSettle();
    expect(find.text('Finished Hall'), findsOneWidget);
    expect(find.text('Velocity Pro Sports Arena'), findsNothing);

    await tester.tap(find.byKey(const Key('booking-filter-declined')));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled Lawn'), findsOneWidget);
    expect(find.text('Rejected Palace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
