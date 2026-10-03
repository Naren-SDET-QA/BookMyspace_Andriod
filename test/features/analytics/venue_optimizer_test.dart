import 'package:bookmyspace/features/analytics/domain/pricing_rules_reader.dart';
import 'package:bookmyspace/features/analytics/domain/venue_optimizer.dart';
import 'package:bookmyspace/features/analytics/presentation/venue_optimizer_providers.dart';
import 'package:bookmyspace/features/analytics/presentation/widgets/venue_optimizer_section.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/owner_booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TimeSlot _slot(String id, String start, String end,
        {double price = 1000, bool active = true, String venue = 'v1'}) =>
    TimeSlot(
      id: id,
      venueId: venue,
      label: id,
      startTime: '$start:00',
      endTime: '$end:00',
      priceAmount: price,
      isActive: active,
    );

Booking _booking(
  String slotId,
  DateTime day, {
  String start = '00:00',
  String end = '00:00',
  BookingStatus status = BookingStatus.confirmed,
  String venue = 'v1',
}) => Booking(
  id: '$slotId-$day',
  bookingRef: 'R',
  venueId: venue,
  slotId: slotId,
  bookDate: day,
  startTime: '$start:00',
  endTime: '$end:00',
  status: status,
  amount: 1000,
  taxAmount: 0,
  totalAmount: 1000,
);

final _d1 = DateTime(2026, 10, 5);
final _d2 = DateTime(2026, 10, 6);

final _slots = [
  _slot('m', '07', '08', price: 500), // Morning
  _slot('e1', '18', '19'), // Evening
  _slot('e2', '19', '20'), // Evening
  _slot('off', '12', '13', active: false), // inactive: ignored
];

void main() {
  group('VenueOptimizerReport', () {
    test('occupancy, windows, unsold value and statuses', () {
      final report = VenueOptimizerReport.build(
        venues: [VenueCapacity(venueId: 'v1', slots: _slots)],
        bookings: [
          _booking('e1', _d1),
          _booking('e2', _d1, status: BookingStatus.held),
          _booking('e1', _d2, status: BookingStatus.awaitingOwnerApproval),
          _booking('e2', _d2, status: BookingStatus.cancelled), // ignored
          _booking('m', DateTime(2026, 10, 9)), // outside range
        ],
        start: _d1,
        end: _d2,
      );
      expect(report.days, 2);
      expect(report.capacity, 6, reason: '3 active slots x 2 days');
      expect(report.occupied, 3);
      expect(report.occupancyPercent, 50);
      expect(report.unsoldValue, 500 + 500 + 1000);
      expect(report.windows.map((w) => w.spec.name), ['Morning', 'Evening']);
      final evening = report.windows.last;
      expect(evening.fillPercent, 75);
      expect(evening.band, DemandBand.moderate);
      expect(report.windows.first.band, DemandBand.low);
      expect(report.recommendations.single.title, 'Fill morning slots');
    });

    test('blocked dates remove capacity', () {
      final report = VenueOptimizerReport.build(
        venues: [
          VenueCapacity(venueId: 'v1', slots: _slots, blockedDates: {_d2}),
        ],
        bookings: [_booking('e1', _d1), _booking('e2', _d1)],
        start: _d1,
        end: _d2,
      );
      expect(report.capacity, 3);
      expect(report.windows.last.fillPercent, 100);
      expect(report.windows.last.band, DemandBand.high);
      expect(
        report.recommendations.map((r) => r.title),
        containsAll(['Fill morning slots', 'Expand evening capacity']),
      );
    });

    test('fully blocked or slotless venues have no inventory', () {
      final blocked = VenueOptimizerReport.build(
        venues: [
          VenueCapacity(venueId: 'v1', slots: _slots, blockedDates: {_d1}),
        ],
        bookings: const [],
        start: _d1,
        end: _d1,
      );
      expect(blocked.hasInventory, isFalse);
      expect(blocked.windows, isEmpty);
      final none = VenueOptimizerReport.build(
        venues: const [VenueCapacity(venueId: 'v1', slots: [])],
        bookings: const [],
        start: _d1,
        end: _d1,
      );
      expect(none.hasInventory, isFalse);
      expect(none.occupancyPercent, 0);
    });

    test('no bookings: zero occupancy and no recommendations', () {
      final report = VenueOptimizerReport.build(
        venues: [VenueCapacity(venueId: 'v1', slots: _slots)],
        bookings: const [],
        start: _d1,
        end: _d1,
      );
      expect(report.occupied, 0);
      expect(report.recommendations, isEmpty);
      expect(report.unsoldValue, 2500);
    });

    test('bookings without a slot id match by overlapping time', () {
      final report = VenueOptimizerReport.build(
        venues: [VenueCapacity(venueId: 'v1', slots: _slots)],
        bookings: [
          // One 18:30-19:30 custom booking overlaps both evening slots.
          _booking('', _d1, start: '18:30', end: '19:30'),
        ],
        start: _d1,
        end: _d1,
      );
      expect(report.occupied, 2);
    });

    test('midnight-crossing slots and late-night window', () {
      final report = VenueOptimizerReport.build(
        venues: [
          VenueCapacity(
            venueId: 'v1',
            slots: [
              _slot('n', '23', '00'), // ends at midnight
              _slot('x', '22', '02'), // crosses midnight
              _slot('l', '01', '03'),
            ],
          ),
        ],
        bookings: [_booking('', _d1, start: '23:30', end: '01:00')],
        start: _d1,
        end: _d1,
      );
      expect(report.windows.map((w) => w.spec.name), ['Late night', 'Night']);
      // 23:30-01:00 overlaps 23:00-24:00 and 22:00-02:00, not 01:00-03:00.
      expect(report.windows.last.occupied, 2);
      expect(report.windows.first.occupied, 0);
    });

    test('venue filter and other venues', () {
      final report = VenueOptimizerReport.build(
        venues: [
          VenueCapacity(venueId: 'v1', slots: _slots),
          VenueCapacity(
            venueId: 'v2',
            slots: [_slot('a', '09', '10', venue: 'v2')],
          ),
        ],
        bookings: [_booking('a', _d1, venue: 'v2')],
        start: _d1,
        end: _d1,
        venueId: 'v2',
      );
      expect(report.capacity, 1);
      expect(report.occupancyPercent, 100);
    });
  });

  group('PricingRuleSummary', () {
    test('B10 schema discounts and surcharges', () {
      final s = PricingRuleSummary.fromJson({
        'venue_id': 'v1',
        'rule_type': 'surcharge',
        'adjustment_percent': 20,
        'day_of_week': 6,
        'label': 'Weekend prime',
      });
      expect(s.isAdjustment, isTrue);
      expect(s.description, 'Weekend prime · +20% surcharge · Sat');
      final d = PricingRuleSummary.fromJson({
        'rule_type': 'discount',
        'adjustment_percent': 15,
      });
      expect(d.description, '15% off · every day');
    });

    test('legacy multiplier schema, including neutral placeholders', () {
      expect(
        PricingRuleSummary.fromJson({
          'price_multiplier': 1.0,
          'kind': 'custom',
        }).isAdjustment,
        isFalse,
      );
      final up = PricingRuleSummary.fromJson({
        'price_multiplier': 1.25,
        'start_date': '2026-12-20',
        'end_date': '2026-12-31',
      });
      expect(up.isAdjustment, isTrue);
      expect(up.description, '+25% surcharge · 2026-12-20 to 2026-12-31');
    });
  });

  group('VenueOptimizerSection layout', () {
    Widget app({
      List<VenueCapacity>? capacity,
      Object? capacityError,
      List<PricingRuleSummary> rules = const [],
      double textScale = 1,
    }) {
      final bookings = [
        _booking('e1', _d1),
        _booking('e2', _d1),
        _booking('e1', _d2),
      ];
      return ProviderScope(
        key: UniqueKey(),
        overrides: [
          ownerCapacityProvider.overrideWith((ref) async {
            if (capacityError != null) throw capacityError;
            return capacity ??
                [VenueCapacity(venueId: 'v1', slots: _slots)];
          }),
          ownerBookingsProvider.overrideWith((ref) async => bookings),
          pricingRulesReaderProvider.overrideWithValue(_Rules(rules)),
          ownerPricingRulesProvider.overrideWith((ref) async => rules),
        ],
        child: MaterialApp(
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  VenueOptimizerSection(start: _d1, end: _d2),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pumpAt(WidgetTester tester, Size size, Widget w) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(w);
      await tester.pumpAndSettle();
    }

    void expectNoClippedText(WidgetTester tester) {
      final section = find.byKey(const Key('venue_optimizer_section'));
      for (final e in find
          .descendant(of: section, matching: find.byType(RichText))
          .evaluate()) {
        final paragraph = e.renderObject! as RenderParagraph;
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'clipped: "${paragraph.text.toPlainText()}"',
        );
      }
    }

    Future<void> checkLayout(WidgetTester tester, Size size, double scale) async {
      await pumpAt(tester, size, app(textScale: scale));
      expect(tester.takeException(), isNull);
      expect(find.text('Venue Yield Optimizer'), findsOneWidget);
      expectNoClippedText(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('optimizer_recommendations_card')),
        200,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
      // Cards never exceed the viewport width.
      for (final key in const [
        'optimizer_heatmap',
        'optimizer_pricing',
        'optimizer_recommendations_card',
      ]) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(rect.left, greaterThanOrEqualTo(0), reason: key);
        expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
      }
      // Two columns exactly where the shared breakpoints say so (the list
      // has 16px padding on each side).
      final heat = tester.getTopLeft(find.byKey(const Key('optimizer_heatmap')));
      final pricing = tester.getTopLeft(
        find.byKey(const Key('optimizer_pricing')),
      );
      expect(
        pricing.dx > heat.dx,
        VenueOptimizerSection.isTwoColumn(size.width - 32),
      );
    }

    // Every width in the device matrix, portrait and landscape.
    const sizes = {
      'small phone 320x568': Size(320, 568),
      'phone 375x667': Size(375, 667),
      'phone 390x844': Size(390, 844),
      'phone 430x932': Size(430, 932),
      'small phone landscape 568x320': Size(568, 320),
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
      'large desktop 2560x1440': Size(2560, 1440),
    };

    for (final entry in sizes.entries) {
      for (final scale in const [1.0, 1.5]) {
        testWidgets('${entry.key} at ${scale}x text', (tester) async {
          await checkLayout(tester, entry.value, scale);
        });
      }
    }

    for (final width in const [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('small screen ${width.toInt()}px at 2x text', (tester) async {
        await checkLayout(tester, Size(width, 800), 2);
      });
    }

    testWidgets('large text (2x) on a small phone stacks KPIs, no overflow', (
      tester,
    ) async {
      await pumpAt(tester, const Size(320, 640), app(textScale: 2));
      expect(tester.takeException(), isNull);
      final occ = tester.getTopLeft(find.byKey(const Key('optimizer_occupancy')));
      final unsold = tester.getTopLeft(find.byKey(const Key('optimizer_unsold')));
      expect(unsold.dy, greaterThan(occ.dy), reason: 'stacked vertically');
    });

    testWidgets('shows real figures, notice, and no pricing write controls', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 2400), app());
      // 3 of 6 slot-days booked.
      expect(find.text('50.0%'), findsOneWidget);
      expect(find.text('3 of 6 slots'), findsOneWidget);
      expect(find.byKey(const Key('optimizer_pricing_notice')), findsOneWidget);
      expect(find.byKey(const Key('optimizer_no_rules')), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('lists only real adjustment rules', (tester) async {
      await pumpAt(
        tester,
        const Size(390, 2400),
        app(
          rules: [
            PricingRuleSummary.fromJson({'price_multiplier': 1.0}),
            PricingRuleSummary.fromJson({
              'rule_type': 'surcharge',
              'adjustment_percent': 20,
              'day_of_week': 0,
            }),
          ],
        ),
      );
      expect(find.text('+20% surcharge · Sun'), findsOneWidget);
      expect(find.text('No change · every day'), findsNothing);
    });

    testWidgets('empty inventory and errors', (tester) async {
      await pumpAt(
        tester,
        const Size(390, 844),
        app(capacity: const [VenueCapacity(venueId: 'v1', slots: [])]),
      );
      expect(find.byKey(const Key('optimizer_no_inventory')), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      await pumpAt(
        tester,
        const Size(390, 844),
        app(capacityError: Exception('offline')),
      );
      expect(find.textContaining('offline'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _Rules implements PricingRulesReader {
  _Rules(this.rules);
  final List<PricingRuleSummary> rules;
  @override
  Future<List<PricingRuleSummary>> forVenues(Iterable<String> venueIds) async =>
      rules;
}
