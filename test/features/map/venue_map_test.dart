import 'package:bookmyspace/features/map/presentation/screens/venue_map_screen.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  group('VenueCluster', () {
    test('identifies single venue correctly', () {
      const venue = Venue(
        id: 'v1',
        name: 'Venue 1',
        latitude: 17.3850,
        longitude: 78.4867,
      );

      const cluster = VenueCluster(
        id: 'v1',
        position: LatLng(17.3850, 78.4867),
        venues: [venue],
      );

      expect(cluster.isSingle, isTrue);
      expect(cluster.singleVenue.id, 'v1');
    });

    test('identifies multi-venue cluster', () {
      const v1 = Venue(
        id: 'v1',
        name: 'Venue 1',
        latitude: 17.3850,
        longitude: 78.4867,
      );
      const v2 = Venue(
        id: 'v2',
        name: 'Venue 2',
        latitude: 17.3860,
        longitude: 78.4870,
      );

      const cluster = VenueCluster(
        id: 'cluster_1',
        position: LatLng(17.3855, 78.4868),
        venues: [v1, v2],
      );

      expect(cluster.isSingle, isFalse);
      expect(cluster.venues.length, 2);
    });
  });
}
