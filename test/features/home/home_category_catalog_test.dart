import 'package:bookmyspace/features/home/presentation/home_category_catalog.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Function Halls exposes the fourteen celebration sub-sections', () {
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
      'Auditoriums',
      'Community Halls',
      'Exhibition Halls',
      'Government Halls',
      'Meeting Rooms',
      'Temples',
    ]);
    // matrixCells is a legacy fixed 3x3 layout that deliberately cherry-picks
    // only the original 8 celebration-hall slugs -- it must stay at 8 even
    // as more sub-sections are added above.
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

  test('Lodges & Stays now includes Guest Houses', () {
    final labels =
        MainHomeSection.lodgeRooms.subSections.map((s) => s.label).toList();
    expect(labels, contains('Guest Houses'));
    expect(
        MainHomeSection.lodgeRooms.subSections
            .firstWhere((s) => s.label == 'Guest Houses')
            .slug,
        'guest_house');
  });

  test(
      'new function-hall sub-sections resolve real venue_categories slugs '
      'instead of inventing records', () {
    const live = [
      VenueCategory(
        id: 'c3',
        slug: 'auditorium',
        name: 'Auditorium',
        parentSection: 'function_halls',
      ),
      VenueCategory(
        id: 'c4',
        slug: 'temple',
        name: 'Temple',
        parentSection: 'function_halls',
      ),
    ];
    final items = MainHomeSection.functionHalls.subSections;
    final auditorium =
        items.firstWhere((s) => s.slug == 'auditorium').match(live);
    final temple = items.firstWhere((s) => s.slug == 'temple').match(live);
    final meetingRoom =
        items.firstWhere((s) => s.slug == 'meeting_room').match(live);
    expect(auditorium?.slug, 'auditorium');
    expect(temple?.slug, 'temple');
    expect(meetingRoom, isNull);
  });
}
