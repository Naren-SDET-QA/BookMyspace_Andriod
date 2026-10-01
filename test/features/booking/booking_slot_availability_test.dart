import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/domain/date_availability.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/booking_screen.dart';
import 'package:bookmyspace/features/venues/domain/listing_template.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_booking_repository.dart';

SlotAvailability _slot(String id, {bool free = true, String? label}) =>
    SlotAvailability(
      slotId: id,
      label: label ?? 'Slot $id',
      startTime: '${(8 + int.parse(id)).toString().padLeft(2, '0')}:00:00',
      endTime: '${(9 + int.parse(id)).toString().padLeft(2, '0')}:00:00',
      priceAmount: 1000,
      isAvailable: free,
      reason: free ? 'available' : 'booked',
    );

/// Throws "slot just taken" once, after which the taken slot shows as booked.
class _RacingBookingRepository extends MockBookingRepository {
  _RacingBookingRepository({required super.slots});

  int requests = 0;

  @override
  Future<Booking> requestBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int approvalMinutes = 120,
    String? couponCode,
    Map<String, dynamic> metadata = const {},
  }) async {
    requests++;
    if (requests == 1) {
      slots = [
        for (final s in slots)
          s.slotId == slotId ? _slot(s.slotId, free: false, label: s.label) : s,
      ];
      throw const BookingConflictException(
        'This slot was just taken. Please pick another.',
        code: 'slot_unavailable',
      );
    }
    return super.requestBooking(
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      amount: amount,
    );
  }
}

const _venue = Venue(
  id: 'v1',
  name: 'Sunrise Function Hall',
  latitude: 0,
  longitude: 0,
  category: VenueCategory(
    id: 'c1',
    slug: 'function_hall',
    name: 'Function Hall',
    listingConfig: ListingTemplateConfig(
      templateId: 'hall',
      fields: [
        ListingFieldDefinition(
          key: 'date',
          label: 'Date',
          type: ListingFieldType.date,
          required: true,
        ),
      ],
    ),
  ),
);

Future<void> _pump(WidgetTester tester, MockBookingRepository repo) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(
            initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
        ),
      ],
      child: const MaterialApp(
        home: BookingScreen(venue: _venue),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DateAvailability.evaluate', () {
    final today = DateTime(2026, 9, 27);
    List<SlotAvailability> slots(int free, int total) => [
      for (var i = 0; i < total; i++) _slot('$i', free: i < free),
    ];

    test('thresholds', () {
      DateAvailabilityStatus s(int free, int total) =>
          DateAvailability.evaluate(
            slots(free, total),
            today,
            now: today,
          ).status;
      expect(s(0, 4), DateAvailabilityStatus.soldOut);
      expect(s(1, 4), DateAvailabilityStatus.limited);
      expect(s(2, 4), DateAvailabilityStatus.limited);
      expect(s(3, 8), DateAvailabilityStatus.fillingFast);
      expect(s(5, 8), DateAvailabilityStatus.fillingFast);
      expect(s(6, 8), DateAvailabilityStatus.available);
      expect(s(0, 0), DateAvailabilityStatus.available);
    });

    test('past dates are not bookable; sold out is not bookable', () {
      final past = DateAvailability.evaluate(
        slots(3, 3),
        DateTime(2026, 9, 26),
        now: today,
      );
      expect(past.status, DateAvailabilityStatus.past);
      expect(past.label, 'Past');
      expect(past.isBookable, isFalse);
      final soldOut = DateAvailability.evaluate(slots(0, 3), today, now: today);
      expect(soldOut.label, 'Sold out');
      expect(soldOut.isBookable, isFalse);
    });

    test('alternatives exclude the taken slot and booked ones', () {
      final list = [_slot('1'), _slot('2', free: false), _slot('3')];
      expect(
        DateAvailability.alternatives(
          list,
          excludeSlotId: '1',
        ).map((s) => s.slotId),
        ['3'],
      );
    });
  });

  testWidgets('shows a Limited badge for the selected date', (tester) async {
    await _pump(
      tester,
      MockBookingRepository(slots: [_slot('1'), _slot('2', free: false)]),
    );
    expect(find.byKey(const Key('date_availability_badge')), findsOneWidget);
    expect(find.text('Limited'), findsOneWidget);
    expect(find.text('1 of 2 slots free'), findsOneWidget);
  });

  testWidgets('sold-out date shows the badge and offers no confirm', (
    tester,
  ) async {
    await _pump(
      tester,
      MockBookingRepository(
        slots: [_slot('1', free: false), _slot('2', free: false)],
      ),
    );
    expect(find.text('Sold out'), findsOneWidget);
    // Booked slots are disabled, so no confirm bar can appear.
    await tester.tap(find.text('Slot 1'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('taken slot offers the other free slots to re-pick', (
    tester,
  ) async {
    final repo = _RacingBookingRepository(
      slots: [
        _slot('1', label: 'Morning'),
        _slot('2', label: 'Afternoon'),
        _slot('3', free: false, label: 'Evening'),
      ],
    );
    await _pump(tester, repo);

    await tester.enterText(
      find.byKey(const Key('booking_customer_name')),
      'Jane Doe',
    );
    await tester.enterText(
      find.byKey(const Key('booking_customer_phone')),
      '9876543210',
    );
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lock_rounded));
    await tester.pumpAndSettle();
    // Confirm dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alternative_slots_sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('alternative_slot_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('alternative_slot_1')), findsNothing);
    expect(find.byKey(const ValueKey('alternative_slot_3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('alternative_slot_2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alternative_slots_sheet')), findsNothing);
    // The re-picked slot is selected: the confirm bar is back.
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
