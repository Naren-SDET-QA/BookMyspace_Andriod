import 'package:bookmyspace/features/home/presentation/home_category_catalog.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Function Halls exposes the eight celebration sub-sections', () {
    final items = MainHomeSection.functionHalls.subSections;
    expect(items.map((s) => s.label).toList(), [
      'Marriage Halls',
      'Banquet Halls',
      'Convention Halls',
      'Party Halls & Lawns',
      'Engagement Halls',
      'Reception Halls',
      'Premium / Luxury Halls',
      'Outdoor / Garden Venues',
    ]);
    expect(
        MainHomeSection.functionHalls.matrixCells.whereType<HomeSubSection>(),
        hasLength(8));
    expect(MainHomeSection.functionHalls.matrixCells[4], isNull);
  });

  test('master category titles match the product catalog', () {
    expect(
      MainHomeSection.discoveryOrder.map((s) => s.displayTitle).toList(),
      [
        'Function Halls & Celebrations',
        'Sports & Recreation',
        'PG & Hostels',
        'Education & Institutes',
        'Lodges & Stays',
      ],
    );
  });

  test('sub-sections match live categories without inventing records', () {
    const live = [
      VenueCategory(
        id: 'c1',
        slug: 'marriage_hall',
        name: 'Marriage Halls',
        parentSection: 'venues',
      ),
      VenueCategory(
        id: 'c2',
        slug: 'party_hall',
        name: 'Party Halls',
        parentSection: 'venues',
      ),
    ];
    final marriage =
        MainHomeSection.functionHalls.subSections.first.match(live);
    final engagement = MainHomeSection.functionHalls.subSections
        .firstWhere((s) => s.slug == 'engagement_hall')
        .match(live);
    expect(marriage?.slug, 'marriage_hall');
    expect(engagement, isNull);
  });
}
