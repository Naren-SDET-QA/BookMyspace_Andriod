import 'package:bookmyspace/features/accommodations/presentation/stay_results_filter.dart';
import 'package:bookmyspace/features/accommodations/presentation/widgets/stay_filter_panel.dart';
import 'package:bookmyspace/features/accommodations/presentation/widgets/stay_results_chrome.dart';
import 'package:bookmyspace/features/home/presentation/discovery_booking_prefs.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _hotel = VenueCategory(id: 'c1', slug: 'hotel', name: 'Hotel');
const _lodge = VenueCategory(id: 'c2', slug: 'lodge', name: 'Lodge');

Venue _venue({
  required String id,
  required String name,
  VenueCategory? category,
  double price = 0,
  double avgRating = 0,
  int? starRating,
  int parkingCapacity = 0,
  String foodOptions = '',
  Map<String, dynamic>? cancellationPolicy,
  List<VenueFacility> facilities = const [],
  double? distanceKm,
}) {
  return Venue(
    id: id,
    name: name,
    latitude: 0,
    longitude: 0,
    category: category,
    price: price,
    avgRating: avgRating,
    starRating: starRating,
    parkingCapacity: parkingCapacity,
    foodOptions: foodOptions,
    cancellationPolicy: cancellationPolicy,
    facilities: facilities,
    distanceKm: distanceKm,
  );
}

void main() {
  final grand = _venue(
    id: 'grand',
    name: 'Grand Hotel',
    category: _hotel,
    price: 4000,
    avgRating: 4.6,
    starRating: 5,
    parkingCapacity: 10,
    foodOptions: 'Breakfast included',
    cancellationPolicy: const {'summary': 'Free cancellation before arrival'},
    facilities: const [
      VenueFacility(facility: 'Pool'),
      VenueFacility(facility: 'Wifi'),
    ],
    distanceKm: 0.8,
  );
  final lodge = _venue(
    id: 'lodge',
    name: 'Palm Lodge',
    category: _lodge,
    price: 1800,
    avgRating: 3.4,
    starRating: 3,
    facilities: const [VenueFacility(facility: 'Wifi')],
    distanceKm: 4.2,
  );
  final quiet = _venue(
    id: 'quiet',
    name: 'Quiet Stay',
    category: _hotel,
    price: 0,
    avgRating: 2,
    cancellationPolicy: const {'summary': 'Non-refundable rate'},
    distanceKm: 2,
  );
  final venues = [grand, lodge, quiet];

  test('property type is an OR match and ladies does not match men', () {
    final filtered = StayResultsFilterEngine.apply(
      venues,
      const StayResultsFilter(propertyTypes: {'hotel', 'lodge'}),
      isPg: false,
    );
    expect(filtered.map((venue) => venue.id), ['grand', 'lodge', 'quiet']);

    final ladies = _venue(
      id: 'women',
      name: 'Women PG',
      category: const VenueCategory(id: 'p', slug: 'pg', name: 'PG'),
    );
    expect(StayResultsFilterEngine.matchesProperty(ladies, 'gents'), isFalse);
    expect(StayResultsFilterEngine.matchesProperty(ladies, 'ladies'), isTrue);
  });

  test('facilities must all match and stars are exact classes', () {
    final withPool = StayResultsFilterEngine.apply(
      venues,
      const StayResultsFilter(facilities: {'pool', 'wifi'}),
      isPg: false,
    );
    expect(withPool.map((venue) => venue.id), ['grand']);

    final stars = StayResultsFilterEngine.apply(
      venues,
      const StayResultsFilter(starClasses: {5, 3}),
      isPg: false,
    );
    expect(stars.map((venue) => venue.id), ['grand', 'lodge']);

    final unrated = StayResultsFilterEngine.apply(
      venues,
      const StayResultsFilter(starClasses: {0}),
      isPg: false,
    );
    expect(unrated.map((venue) => venue.id), ['quiet']);
  });

  test('free cancellation ignores non-refundable copy', () {
    expect(StayResultsFilterEngine.hasFreeCancellation(grand), isTrue);
    expect(StayResultsFilterEngine.hasFreeCancellation(quiet), isFalse);
    final filtered = StayResultsFilterEngine.apply(
      venues,
      const StayResultsFilter(freeCancellation: true),
      isPg: false,
    );
    expect(filtered.map((venue) => venue.id), ['grand']);
  });

  test('budget hides price on request and rating uses the 5-point scale', () {
    final priced = StayResultsFilterEngine.apply(
      venues,
      const StayResultsFilter(minPrice: 2000, maxPrice: 5000),
      isPg: false,
    );
    expect(priced.map((venue) => venue.id), ['grand']);

    final rated = StayResultsFilterEngine.apply(
      venues,
      const StayResultsFilter(minRating: 4.5),
      isPg: false,
    );
    expect(rated.map((venue) => venue.id), ['grand']);
    expect(StayReviewCopy.adjective(4.6), 'Wonderful');
    expect(StayReviewCopy.adjective(4), 'Very good');
  });

  test('distance and price sort keep missing values last', () {
    final nearby = StayResultsFilterEngine.apply(
      venues,
      const StayResultsFilter(maxDistanceKm: 1),
      isPg: false,
    );
    expect(nearby.map((venue) => venue.id), ['grand']);

    final sorted = StayResultsFilterEngine.sort(venues, StaySort.priceLow);
    expect(sorted.map((venue) => venue.id), ['lodge', 'grand', 'quiet']);
    expect(StayResultsFilterEngine.priceCeiling(venues), 4000);
  });

  test('facet counts ignore the selection inside the same group', () {
    final hotels = StayResultsFilterEngine.count(
      venues,
      const StayResultsFilter(
        propertyTypes: {'lodge'},
      ).without(StayFacet.propertyType).copyWith(propertyTypes: {'hotel'}),
      isPg: false,
    );
    expect(hotels, 2);
    expect(const StayResultsFilter(starClasses: {3, 5}).serverMinStar, 3);
    expect(const StayResultsFilter(starClasses: {0}).serverMinStar, isNull);
  });

  testWidgets('filter column toggles a property type and shows its count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    StayResultsFilter? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 800,
            child: StayFilterPanel(
              venues: venues,
              filter: const StayResultsFilter(),
              isPg: false,
              priceCeiling: 4000,
              onChanged: (filter) => changed = filter,
              onClear: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Filter by:'), findsOneWidget);
    expect(find.text('Your budget'), findsOneWidget);
    expect(find.text('Popular filters'), findsOneWidget);
    expect(find.text('Free cancellation'), findsOneWidget);
    expect(find.text('Property rating'), findsOneWidget);
    expect(find.text('Breakfast included'), findsOneWidget);

    final hotel = find.byKey(
      const Key('stay_property_hotel'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(hotel, 80);
    await tester.tap(hotel);
    await tester.pump();
    expect(changed?.propertyTypes, {'hotel'});
  });

  testWidgets('filter chips and groups load before any venue matches', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StayFilterChipBar(
                filter: const StayResultsFilter(),
                isPg: false,
                priceCeiling: 0,
                onChanged: (_) {},
                onOpenAll: () {},
              ),
              Expanded(
                child: StayFilterPanel(
                  venues: const [],
                  filter: const StayResultsFilter(),
                  isPg: false,
                  priceCeiling: 0,
                  onChanged: (_) {},
                  onClear: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Property type'), findsWidgets);
    expect(find.text('Review score'), findsWidgets);
    expect(find.text('Budget', skipOffstage: false), findsOneWidget);
    expect(find.text('Your budget'), findsOneWidget);
    expect(find.text('Hotels'), findsOneWidget);
    expect(find.byKey(const Key('stay_star_5')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search bar fits a phone and a desktop width', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final prefs = DiscoveryBookingPrefs(date: DateTime(2026, 9, 30));

    Future<void> pumpAt(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
          home: Scaffold(
            body: StaySearchBar(
              isPg: false,
              controller: controller,
              hasSearch: false,
              prefs: prefs,
              onChanged: (_) {},
              onClear: () {},
              onPickDates: () {},
              onPickGuests: () {},
              onSearch: () {},
            ),
          ),
        ),
      );
      expect(find.text('Where are you going?'), findsOneWidget);
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('Check-out'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await pumpAt(const Size(390, 844));
    await pumpAt(const Size(1280, 800));
    await tester.binding.setSurfaceSize(null);
  });
}
