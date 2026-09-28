import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:bookmyspace/features/booking/presentation/widgets/booking_start_countdown.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository_release.dart';
import '../notifications/mock_notification_repository.dart';
import 'mock_booking_repository.dart';

Booking _booking({
  DateTime? day,
  String start = '10:00:00',
  String end = '12:00:00',
  BookingStatus status = BookingStatus.confirmed,
  String id = 'b1',
}) => Booking(
  id: id,
  bookingRef: 'BMS-$id',
  venueId: 'v1',
  slotId: 's1',
  bookDate: day ?? DateTime(2026, 10, 1),
  startTime: start,
  endTime: end,
  status: status,
  amount: 100,
  taxAmount: 0,
  totalAmount: 100,
  venueName: 'Sunrise Function Hall',
);

void main() {
  group('BookingCountdown.compute', () {
    final b = _booking();

    test('upcoming more than a day ahead, formatted Xd hh:mm:ss', () {
      final info = BookingCountdown.compute(
        b,
        DateTime(2026, 9, 29, 8, 58, 55),
      )!;
      expect(info.phase, BookingCountdownPhase.upcoming);
      expect(info.formatted, '2d 01:01:05');
    });

    test('imminent within 24h, urgent within 1h', () {
      expect(
        BookingCountdown.compute(b, DateTime(2026, 9, 30, 10))!.phase,
        BookingCountdownPhase.imminent,
      );
      final urgent = BookingCountdown.compute(b, DateTime(2026, 10, 1, 9, 30))!;
      expect(urgent.phase, BookingCountdownPhase.urgent);
      expect(urgent.formatted, '00:30:00');
    });

    test('in progress between start and end', () {
      final info = BookingCountdown.compute(b, DateTime(2026, 10, 1, 11))!;
      expect(info.phase, BookingCountdownPhase.inProgress);
      expect(info.remaining, const Duration(hours: 1));
    });

    test('no end time means start + 1h', () {
      final noEnd = _booking(end: '');
      expect(
        BookingCountdown.compute(noEnd, DateTime(2026, 10, 1, 10, 30))!.phase,
        BookingCountdownPhase.inProgress,
      );
      expect(
        BookingCountdown.compute(noEnd, DateTime(2026, 10, 1, 11, 1)),
        isNull,
      );
    });

    test('overnight end wraps to the next day', () {
      final overnight = _booking(start: '22:00', end: '02:00');
      expect(
        BookingCountdown.compute(overnight, DateTime(2026, 10, 2, 1))!.phase,
        BookingCountdownPhase.inProgress,
      );
    });

    test('hidden for past, cancelled and unconfirmed bookings', () {
      expect(BookingCountdown.compute(b, DateTime(2026, 10, 1, 13)), isNull);
      for (final status in [
        BookingStatus.cancelled,
        BookingStatus.pending,
        BookingStatus.completed,
      ]) {
        expect(
          BookingCountdown.compute(
            _booking(status: status),
            DateTime(2026, 9, 1),
          ),
          isNull,
          reason: status.name,
        );
      }
    });
  });

  testWidgets('ticks every second and stops cleanly on dispose', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 1, 9, 59, 58);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: BookingStartCountdown(booking: _booking(), now: () => now),
          ),
        ),
      ),
    );
    expect(find.text('00:00:02'), findsOneWidget);
    expect(find.text('Starting soon'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:00:01'), findsOneWidget);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('In progress'), findsOneWidget);

    // Past the end: the banner hides itself.
    now = DateTime(2026, 10, 1, 12, 0, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('booking_start_countdown')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    // No pending timers remain (the test framework would fail otherwise).
  });

  testWidgets('cancelled booking renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookingStartCountdown(
          booking: _booking(status: BookingStatus.cancelled),
          now: () => DateTime(2026, 9, 1),
        ),
      ),
    );
    expect(find.byKey(const Key('booking_start_countdown')), findsNothing);
  });

  testWidgets(
    'My Bookings shows the countdown on upcoming confirmed bookings',
    (tester) async {
      FeatureRegistry.reset();
      addTearDown(FeatureRegistry.reset);
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final future = DateTime.now().add(const Duration(days: 3));
      final day = DateTime(future.year, future.month, future.day);
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
                  _booking(id: 'c1', day: day),
                  _booking(id: 'x1', day: day, status: BookingStatus.cancelled),
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
            home: MyBookingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('booking_start_countdown')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
