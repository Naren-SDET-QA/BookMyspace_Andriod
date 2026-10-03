import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/domain/slot_demand.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/booking_screen.dart';
import 'package:bookmyspace/features/booking/presentation/widgets/peak_booking_hours_card.dart';
import 'package:bookmyspace/features/venues/domain/listing_template.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_booking_repository.dart';

SlotAvailability _slot(String start, {String reason = 'available'}) =>
    SlotAvailability(
      slotId: start,
      label: 'Slot $start',
      startTime: '$start:00',
      endTime: '$start:59',
      priceAmount: 500,
      isAvailable: reason == 'available',
      reason: reason,
    );

// 2026-10-05 is a Monday, 2026-10-10 a Saturday.
final _monday = DateTime(2026, 10, 5);
final _tuesday = DateTime(2026, 10, 6);
final _saturday = DateTime(2026, 10, 10);
final _beforeAll = DateTime(2026, 10, 1, 6);

Map<DateTime, List<SlotAvailability>> _sample() => {
  _monday: [
    _slot('08'),
    _slot('18', reason: 'booked'),
    _slot('20', reason: 'blocked'),
  ],
  _tuesday: [
    _slot('08'),
    _slot('18', reason: 'held'),
    _slot('20'),
  ],
  _saturday: [_slot('08', reason: 'booked'), _slot('18')],
};

/// Records every availability request. 23:00 is booked daily and 18:00 on
/// weekdays.
class _CountingRepo extends MockBookingRepository {
  _CountingRepo({this.failAll = false, this.failDates = const {}});

  final bool failAll;
  final Set<int> failDates; // day offsets from today that fail
  final calls = <DateTime>[];

  @override
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  }) async {
    calls.add(date);
    final now = DateTime.now();
    final offset = date
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (failAll || failDates.contains(offset)) {
      throw Exception('network down');
    }
    // 23:00 is booked every day, so the forecast has a signal whatever day
    // or time the test runs; 22:00 stays free so it can be picked.
    final weekend = DemandDayType.of(date) == DemandDayType.weekend;
    return [
      _slot('23', reason: 'booked'),
      _slot('22'),
      _slot('18', reason: weekend ? 'available' : 'booked'),
    ];
  }
}

const _venue = Venue(
  id: 'v1',
  name: 'Sunrise Court',
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

Future<void> _pumpScreen(
  WidgetTester tester,
  MockBookingRepository repo,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
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
      child: MaterialApp(
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: const BookingScreen(venue: _venue),
        localizationsDelegates: const [
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
  group('SlotDemandForecast', () {
    test('counts booked and held, skips blocked, splits day types', () {
      final weekday = SlotDemandForecast.build(
        _sample(),
        DemandDayType.weekday,
        now: _beforeAll,
      );
      expect(weekday.sampledDays, 2);
      expect(weekday.forHour(18)!.percent, 100);
      expect(weekday.forHour(8)!.percent, 0);
      expect(weekday.forHour(20)!.total, 1, reason: 'blocked is excluded');
      expect(weekday.peak!.hour, 18);
      expect(weekday.best!.hour, 8);
      expect(weekday.forHour(18)!.level, CrowdLevel.peak);

      final weekend = SlotDemandForecast.build(
        _sample(),
        DemandDayType.weekend,
        now: _beforeAll,
      );
      expect(weekend.peak!.hour, 8);
      expect(weekend.best!.hour, 18);
    });

    test('no bookings has no signal', () {
      final f = SlotDemandForecast.build({
        _monday: [_slot('08'), _slot('09')],
      }, DemandDayType.weekday, now: _beforeAll);
      expect(f.hasSignal, isFalse);
      expect(f.hours, hasLength(2));
    });

    test('fully booked hours read 100% peak', () {
      final f = SlotDemandForecast.build({
        _monday: [_slot('10', reason: 'booked'), _slot('11', reason: 'held')],
      }, DemandDayType.weekday, now: _beforeAll);
      expect(f.hours.every((h) => h.percent == 100), isTrue);
      expect(f.best!.level, CrowdLevel.peak);
    });

    test('no bookable slots (all blocked / inactive / unknown) is empty', () {
      final f = SlotDemandForecast.build({
        _monday: [
          _slot('10', reason: 'blocked'),
          _slot('11', reason: 'inactive'),
          _slot('12', reason: 'maintenance'),
        ],
      }, DemandDayType.weekday, now: _beforeAll);
      expect(f.hours, isEmpty);
      expect(f.hasSignal, isFalse);
    });

    test('missing or partial data only uses the dates that loaded', () {
      expect(
        SlotDemandForecast.build(
          const {},
          DemandDayType.weekday,
          now: _beforeAll,
        ).hours,
        isEmpty,
      );
      final partial = SlotDemandForecast.build({
        _tuesday: [_slot('09', reason: 'booked'), _slot('10')],
      }, DemandDayType.weekday, now: _beforeAll);
      expect(partial.sampledDays, 1);
      expect(partial.forHour(9)!.percent, 100);
    });

    test("today's already-started open slots and past dates are ignored", () {
      final now = DateTime(2026, 10, 5, 12, 30); // Monday 12:30
      final f = SlotDemandForecast.build({
        DateTime(2026, 10, 2): [_slot('09', reason: 'booked')], // past date
        _monday: [
          _slot('09'), // started, still "available" in the RPC: excluded
          _slot('11', reason: 'booked'), // started but booked: counted
          _slot('14'),
        ],
      }, DemandDayType.weekday, now: now);
      expect(f.sampledDays, 1);
      expect(f.forHour(9), isNull);
      expect(f.forHour(11)!.percent, 100);
      expect(f.forHour(14)!.percent, 0);
    });

    test('overnight venues read in operating order', () {
      expect(
        SlotDemandForecast.operatingOrder([0, 1, 18, 19, 23]),
        [18, 19, 23, 0, 1],
      );
      expect(SlotDemandForecast.operatingOrder([9, 8, 22]), [8, 9, 22]);
      expect(SlotDemandForecast.operatingOrder([5]), [5]);
      final f = SlotDemandForecast.build({
        _monday: [_slot('00'), _slot('22', reason: 'booked'), _slot('23')],
      }, DemandDayType.weekday, now: _beforeAll);
      expect(f.hours.map((h) => h.label), ['10 PM', '11 PM', '12 AM']);
    });

    test('invalid times are skipped and thresholds hold', () {
      expect(SlotDemandForecast.hourOf('24:00:00'), isNull);
      expect(SlotDemandForecast.hourOf('x'), isNull);
      expect(SlotDemandForecast.hourOf('00:15:00'), 0);
      expect(CrowdLevel.of(75), CrowdLevel.peak);
      expect(CrowdLevel.of(45), CrowdLevel.moderate);
      expect(CrowdLevel.of(44.9), CrowdLevel.quiet);
    });
  });

  group('venueDemandSlotsProvider', () {
    test('shares the per-date slot requests with the slot list', () async {
      final repo = _CountingRepo();
      final container = ProviderContainer(
        overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // The slot list for today is already loaded.
      final listSub = container.listen(
        slotAvailabilityProvider(
          SlotAvailabilityQuery(venueId: 'v1', date: today),
        ),
        (_, __) {},
      );
      await container.read(
        slotAvailabilityProvider(
          SlotAvailabilityQuery(venueId: 'v1', date: today),
        ).future,
      );
      final sub = container.listen(venueDemandSlotsProvider('v1'), (_, __) {});
      final data = await container.read(venueDemandSlotsProvider('v1').future);
      expect(data, hasLength(venueDemandWindowDays));
      expect(repo.calls, hasLength(venueDemandWindowDays));
      expect(repo.calls.toSet(), hasLength(venueDemandWindowDays));
      sub.close();
      listSub.close();
    });

    test('partial failures are skipped', () async {
      final repo = _CountingRepo(failDates: {1, 2});
      final container = ProviderContainer(
        overrides: [bookingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(venueDemandSlotsProvider('v1'), (_, __) {});
      final data = await container.read(venueDemandSlotsProvider('v1').future);
      expect(data, hasLength(venueDemandWindowDays - 2));
      sub.close();
    });

    test('a total network failure surfaces as an error', () async {
      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(
            _CountingRepo(failAll: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(venueDemandSlotsProvider('v1'), (_, __) {});
      await expectLater(
        container.read(venueDemandSlotsProvider('v1').future),
        throwsA(isA<Exception>()),
      );
      sub.close();
    });
  });

  group('PeakBookingHoursCard', () {
    Widget card({
      required DateTime date,
      String? slotStart,
      Future<Map<DateTime, List<SlotAvailability>>> Function()? load,
      Key? scopeKey,
    }) => ProviderScope(
      // A fresh scope per pump (unless a key is kept) so each case gets its
      // own overrides; a kept key exercises didUpdateWidget on the card.
      key: scopeKey ?? UniqueKey(),
      overrides: [
        venueDemandSlotsProvider.overrideWith(
          (ref, id) => (load ?? () async => _sample())(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PeakBookingHoursCard(
              venueId: 'v1',
              selectedDate: date,
              selectedSlotStart: slotStart,
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );

    // The card filters out dates before today, so use future dates.
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day + 7);
    final weekday = base.add(
      Duration(days: (DateTime.monday - base.weekday + 7) % 7),
    );
    final saturday = weekday.add(const Duration(days: 5));
    Map<DateTime, List<SlotAvailability>> future() => {
      weekday: [_slot('08'), _slot('18', reason: 'booked')],
      saturday: [_slot('08', reason: 'booked'), _slot('18')],
    };

    testWidgets('slot pick, day type, taps and date changes', (tester) async {
      await tester.pumpWidget(card(date: weekday, load: () async => future(), scopeKey: const ValueKey('keep')));
      await tester.pumpAndSettle();
      expect(find.text('Best 8 AM · Busiest 6 PM'), findsOneWidget);
      expect(find.text('0% booked (Quiet)'), findsOneWidget);
      expect(find.text('100% booked (Peak Crowd)'), findsOneWidget);

      await tester.pumpWidget(
        card(date: weekday, slotStart: '18:00:00', load: () async => future(), scopeKey: const ValueKey('keep')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your slot · 6 PM'), findsOneWidget);

      // Tap the left edge: inspects 8 AM, no longer "your slot".
      final chart = tester.getRect(find.byKey(const Key('peak_chart')));
      await tester.tapAt(Offset(chart.left + 30, chart.center.dy));
      await tester.pumpAndSettle();
      final focus = find.byKey(const Key('peak_focus_row'));
      expect(
        find.descendant(of: focus, matching: find.text('8 AM')),
        findsOneWidget,
      );

      // Changing the date to a Saturday switches to weekend data and
      // re-follows the picked slot (6 PM is quiet on weekends).
      await tester.pumpWidget(
        card(date: saturday, slotStart: '18:00:00', load: () async => future(), scopeKey: const ValueKey('keep')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Best 6 PM · Busiest 8 AM'), findsOneWidget);
      expect(find.text('Your slot · 6 PM'), findsOneWidget);

      // Manually viewing weekdays for a Saturday slot: no "your slot" label.
      await tester.tap(find.text('Weekdays'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your slot'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no bookings, no slots and errors show messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        card(
          date: weekday,
          load: () async => {
            weekday: [_slot('08'), _slot('09')],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No bookings yet'), findsWidgets);
      expect(find.byKey(const Key('peak_chart')), findsNothing);

      await tester.pumpWidget(
        card(date: weekday, load: () async => const {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('No open weekday slots in the next 14 days.'), findsOneWidget);

      await tester.pumpWidget(
        card(date: weekday, load: () async => throw Exception('offline')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Crowd data is unavailable right now.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BookingScreen integration', () {
    testWidgets('phone: collapsed card adds no requests, opens without '
        'overflow', (tester) async {
      final repo = _CountingRepo();
      await _pumpScreen(tester, repo, const Size(360, 640));
      expect(find.byKey(const Key('peak_booking_hours_card')), findsOneWidget);
      expect(repo.calls.toSet(), hasLength(1), reason: 'only the slot list');

      await tester.tap(find.byKey(const Key('peak_booking_hours_toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(repo.calls, hasLength(venueDemandWindowDays),
          reason: 'selected date is reused, not refetched');

      // Collapse and reopen: no refetch.
      await tester.tap(find.byKey(const Key('peak_booking_hours_toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('peak_booking_hours_toggle')));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(venueDemandWindowDays));
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(800, 1100), Size(1400, 900)]) {
      testWidgets('${size.width.toInt()}px layout renders without overflow '
          'and follows slot selection', (tester) async {
        final repo = _CountingRepo();
        await _pumpScreen(tester, repo, size);
        if (size.width < 840) {
          await tester.tap(find.byKey(const Key('peak_booking_hours_toggle')));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(repo.calls, hasLength(venueDemandWindowDays));

        final slot = find.textContaining('Slot 22');
        if (slot.evaluate().isEmpty) {
          // Wide layout: the slot list sits below the card in the form's
          // lazily built ListView.
          await tester.scrollUntilVisible(
            slot,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tester.ensureVisible(slot.first);
        await tester.tap(slot.first);
        await tester.pumpAndSettle();
        final focus = find.byKey(const Key('peak_focus_row'));
        await tester.ensureVisible(focus);
        expect(
          find.descendant(of: focus, matching: find.textContaining('10 PM')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Device matrix (booking screen)', () {
    const sizes = {
      'small phone 320x568': Size(320, 568),
      'phone 375x667': Size(375, 667),
      'phone 390x844': Size(390, 844),
      'phone 430x932': Size(430, 932),
      'phone landscape 844x390': Size(844, 390),
      'phone landscape 932x430': Size(932, 430),
      'tablet portrait 600x960': Size(600, 960),
      'tablet portrait 768x1024': Size(768, 1024),
      'tablet landscape 840x600': Size(840, 600),
      'tablet landscape 1024x768': Size(1024, 768),
      'desktop 1200x800': Size(1200, 800),
      'desktop 1280x800': Size(1280, 800),
      'desktop 1440x900': Size(1440, 900),
      'large desktop 1920x1080': Size(1920, 1080),
    };

    Future<void> check(WidgetTester tester, Size size, double scale) async {
      await _pumpScreen(tester, _CountingRepo(), size, textScale: scale);
      expect(tester.takeException(), isNull);
      final card = find.byKey(const Key('peak_booking_hours_card'));
      if (card.evaluate().isEmpty) {
        // Short wide screens: the card is below the fold of the form's
        // lazily built list.
        await tester.scrollUntilVisible(
          card,
          150,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      expect(card, findsOneWidget);
      if (find.byKey(const Key('peak_chart')).evaluate().isEmpty) {
        await tester.ensureVisible(
          find.byKey(const Key('peak_booking_hours_toggle')),
        );
        await tester.tap(find.byKey(const Key('peak_booking_hours_toggle')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      // Header toggle and day buttons stay comfortably tappable.
      expect(
        tester.getSize(find.byKey(const Key('peak_booking_hours_toggle'))).height,
        greaterThanOrEqualTo(48),
      );
      final rect = tester.getRect(card);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      for (final e in find
          .descendant(of: card, matching: find.byType(RichText))
          .evaluate()) {
        final p = e.renderObject! as RenderParagraph;
        expect(p.didExceedMaxLines, isFalse,
            reason: 'clipped: "${p.text.toPlainText()}"');
      }
    }

    // Full screen at 1x. Larger text is covered on the card alone below:
    // the screen's existing date strip (listing_availability.dart, fixed
    // 76px chips) already overflows at 1.5x text, independent of this card.
    for (final entry in sizes.entries) {
      testWidgets('${entry.key} at 1.0x text', (tester) async {
        await check(tester, entry.value, 1);
      });
    }
  });

  group('Device matrix (card, large text)', () {
    Future<void> check(WidgetTester tester, Size size, double scale) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(_CountingRepo()),
          ],
          child: MaterialApp(
            home: MediaQuery.withClampedTextScaling(
              minScaleFactor: scale,
              maxScaleFactor: scale,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PeakBookingHoursCard(
                    venueId: 'v1',
                    selectedDate: today,
                    selectedSlotStart: '22:00:00',
                    initiallyExpanded: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = find.byKey(const Key('peak_booking_hours_card'));
      expect(find.byKey(const Key('peak_chart')), findsOneWidget);
      final rect = tester.getRect(card);
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(
        tester.getSize(find.byKey(const Key('peak_booking_hours_toggle'))).height,
        greaterThanOrEqualTo(48),
      );
      for (final e in find
          .descendant(of: card, matching: find.byType(RichText))
          .evaluate()) {
        final p = e.renderObject! as RenderParagraph;
        expect(p.didExceedMaxLines, isFalse,
            reason: 'clipped: "${p.text.toPlainText()}"');
      }
    }

    const sizes = {
      'small phone 320x568': Size(320, 568),
      'phone 375x667': Size(375, 667),
      'phone 390x844': Size(390, 844),
      'phone 430x932': Size(430, 932),
      'phone landscape 844x390': Size(844, 390),
      'tablet portrait 768x1024': Size(768, 1024),
      'tablet landscape 1024x768': Size(1024, 768),
      'desktop 1440x900': Size(1440, 900),
      'large desktop 1920x1080': Size(1920, 1080),
    };
    for (final entry in sizes.entries) {
      testWidgets('${entry.key} at 1.5x text', (tester) async {
        await check(tester, entry.value, 1.5);
      });
    }
    for (final width in const [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('small screen ${width.toInt()}px at 2x text', (tester) async {
        await check(tester, Size(width, 800), 2);
      });
    }
  });
}
