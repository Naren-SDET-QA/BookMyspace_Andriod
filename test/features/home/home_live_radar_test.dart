import 'package:bookmyspace/features/home/presentation/widgets/home_feed_sections.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Venue _venue({
  required String id,
  String name = 'A space',
  String city = 'Hyderabad',
  double? distanceKm,
  double rating = 4.2,
  List<VenueImage> images = const [],
}) {
  return Venue(
    id: id,
    name: name,
    latitude: 17.4,
    longitude: 78.5,
    city: city,
    avgRating: rating,
    distanceKm: distanceKm,
    images: images,
  );
}

void main() {
  group('nearestFirst', () {
    test('orders by distance, closest first', () {
      final sorted = HomeLiveRadar.nearestFirst([
        _venue(id: 'c', distanceKm: 9.4),
        _venue(id: 'a', distanceKm: 0.4),
        _venue(id: 'b', distanceKm: 3.1),
      ]);
      expect(sorted.map((v) => v.id), ['a', 'b', 'c']);
    });

    test('keeps an unknown distance at the back instead of dropping it', () {
      final sorted = HomeLiveRadar.nearestFirst([
        _venue(id: 'unknown'),
        _venue(id: 'far', distanceKm: 12),
        _venue(id: 'near', distanceKm: 1),
      ]);
      expect(sorted.map((v) => v.id), ['near', 'far', 'unknown']);
    });

    test('does not mutate the list it was handed', () {
      final input = [
        _venue(id: 'b', distanceKm: 5),
        _venue(id: 'a', distanceKm: 1),
      ];
      HomeLiveRadar.nearestFirst(input);
      expect(input.map((v) => v.id), ['b', 'a']);
    });
  });

  group('distanceLabel', () {
    test('shows kilometres to one decimal', () {
      expect(
        HomeLiveRadar.distanceLabel(_venue(id: 'a', distanceKm: 3.14)),
        '3.1 km',
      );
    });

    test('shows metres below a kilometre', () {
      expect(
        HomeLiveRadar.distanceLabel(_venue(id: 'a', distanceKm: 0.42)),
        '420 m',
      );
    });

    test('falls back to the city when no distance is known', () {
      expect(
        HomeLiveRadar.distanceLabel(
          _venue(id: 'a', city: 'Vijayawada'),
        ),
        'Vijayawada',
      );
    });
  });

  group('coverUrl', () {
    test('is empty when the venue has no artwork', () {
      expect(HomeLiveRadar.coverUrl(_venue(id: 'a')), isEmpty);
    });

    test('prefers an explicit cover over sort order', () {
      final venue = _venue(
        id: 'a',
        images: const [
          VenueImage(id: '1', url: 'https://x/first.jpg'),
          VenueImage(
            id: '2',
            url: 'https://x/cover.jpg',
            isCover: true,
            sortOrder: 9,
          ),
        ],
      );
      expect(HomeLiveRadar.coverUrl(venue), 'https://x/cover.jpg');
    });

    test('falls back to the lowest sort order', () {
      final venue = _venue(
        id: 'a',
        images: const [
          VenueImage(id: '1', url: 'https://x/late.jpg', sortOrder: 4),
          VenueImage(id: '2', url: 'https://x/early.jpg', sortOrder: 1),
        ],
      );
      expect(HomeLiveRadar.coverUrl(venue), 'https://x/early.jpg');
    });

    test('prefers the thumbnail when the cover has one', () {
      final venue = _venue(
        id: 'a',
        images: const [
          VenueImage(
            id: '1',
            url: 'https://x/full.jpg',
            thumbnailUrl: 'https://x/thumb.jpg',
          ),
        ],
      );
      expect(HomeLiveRadar.coverUrl(venue), 'https://x/thumb.jpg');
    });
  });

  group('HomeLiveRadar', () {
    testWidgets('renders nothing at all without a location', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeLiveRadar(venues: [], title: 'Nearest spaces'),
          ),
        ),
      );

      expect(find.text('Nearest spaces'), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('shows the nearest three, closest first', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeLiveRadar(
              venues: [
                _venue(id: 'c', name: 'Far Hall', distanceKm: 9.4),
                _venue(id: 'a', name: 'Near Cafe', distanceKm: 0.42),
                _venue(id: 'b', name: 'Mid Studio', distanceKm: 3.1),
                _venue(id: 'd', name: 'Furthest Hall', distanceKm: 20),
              ],
              title: 'Nearest spaces',
            ),
          ),
        ),
      );

      expect(find.text('Nearest spaces'), findsOneWidget);
      expect(find.text('Near Cafe'), findsOneWidget);
      expect(find.text('Mid Studio'), findsOneWidget);
      expect(find.text('Far Hall'), findsOneWidget);
      // Capped at three, so the furthest venue never renders.
      expect(find.text('Furthest Hall'), findsNothing);
      expect(find.text('420 m'), findsOneWidget);
      expect(find.text('3.1 km'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports the venue the reader tapped', (tester) async {
      Venue? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeLiveRadar(
              venues: [_venue(id: 'a', name: 'Near Cafe', distanceKm: 0.42)],
              title: 'Nearest spaces',
              onVenueTap: (venue) => tapped = venue,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Near Cafe'));
      expect(tapped?.id, 'a');
    });
  });
}
