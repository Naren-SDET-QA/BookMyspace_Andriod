import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/venue_discovery/domain/discovered_place.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';

void main() {
  test('parses Nominatim place metadata without inventing coordinates', () {
    final place = DiscoveredPlace.fromNominatim({
      'osm_type': 'node',
      'osm_id': 12,
      'name': 'City Hall',
      'display_name': 'City Hall, Main Road, Hyderabad',
      'lat': '17.3850',
      'lon': '78.4867',
      'type': 'townhall',
      'address': {'road': 'Main Road', 'city': 'Hyderabad'},
      'extratags': {'website': 'https://example.test'},
    });

    expect(place.id, 'node:12');
    expect(place.latitude, 17.3850);
    expect(place.address, 'Main Road, Hyderabad');
    expect(place.website, 'https://example.test');
  });

  test('deduplicates external places by name and nearby coordinates', () {
    const venue = Venue(
      id: 'venue-1',
      name: 'City Hall',
      latitude: 17.3850,
      longitude: 78.4867,
    );
    const places = [
      DiscoveredPlace(
        id: 'osm:1',
        name: 'City Hall',
        displayName: 'City Hall',
        latitude: 17.3851,
        longitude: 78.4868,
      ),
      DiscoveredPlace(
        id: 'osm:2',
        name: 'Open Grounds',
        displayName: 'Open Grounds',
        latitude: 17.50,
        longitude: 78.60,
      ),
      DiscoveredPlace(
        id: 'osm:3',
        name: 'Open Grounds',
        displayName: 'Open Grounds duplicate',
        latitude: 17.51,
        longitude: 78.61,
      ),
    ];

    final result = DiscoveredPlace.deduplicate(places, [venue]);

    expect(result.map((place) => place.id), ['osm:2']);
  });
}
