import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps deployed venue address and category metadata columns', () {
    final venue = Venue.fromJson({
      'id': 'venue-1',
      'name': 'BookMySpace Test Venue',
      'address_line1': '1 Main Street',
      'city': 'Hyderabad',
      'state': 'Telangana',
      'postal_code': '500081',
      'latitude': 17.4,
      'longitude': 78.4,
      'venue_categories': {
        'id': 'category-1',
        'slug': 'meeting_room',
        'name': 'Meeting Room',
        'metadata': {
          'is_active': false,
          'parent_section': 'venues',
        },
      },
    });

    expect(venue.address, '1 Main Street');
    expect(venue.pincode, '500081');
    expect(venue.category?.isActive, isFalse);
    expect(venue.category?.parentSection, 'venues');
  });

  test('maps the deployed active category metadata key', () {
    final category = VenueCategory.fromJson({
      'id': 'category-2',
      'slug': 'studio',
      'name': 'Studio',
      'metadata': {'active': false},
    });

    expect(category.isActive, isFalse);
  });
}
