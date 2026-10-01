import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Venue parse(List<Map<String, dynamic>> media, {int? stars}) =>
      Venue.fromJson({
        'id': 'v1',
        'name': 'Grand Hall',
        'latitude': 17.0,
        'longitude': 78.0,
        if (stars != null) 'star_rating': stars,
        'venue_images': media,
      });

  test('video and tour rows are not gallery images', () {
    final venue = parse([
      {'id': 'a', 'url': 'https://x.test/a.jpg', 'media_kind': 'image'},
      {'id': 'b', 'url': 'https://x.test/walk.mp4', 'media_kind': 'video'},
      {'id': 'c', 'url': 'https://x.test/hall.glb', 'media_kind': 'model_3d'},
      {'id': 'd', 'url': 'https://x.test/b.jpg'},
    ]);
    expect(venue.images.map((i) => i.id), ['a', 'd']);
    expect(venue.videoUrl, 'https://x.test/walk.mp4');
    expect(venue.tourUrl, 'https://x.test/hall.glb');
    expect(venue.tourIsModel, isTrue);
  });

  test('360 links open externally, not in the model viewer', () {
    final venue = parse([
      {
        'id': 't',
        'url': 'https://my.matterport.com/show/?m=abc',
        'media_kind': 'model_3d',
      },
    ]);
    expect(venue.tourUrl, isNotEmpty);
    expect(venue.tourIsModel, isFalse);
    expect(venue.images, isEmpty);
  });

  test('star_rating parses and is independent of avg rating', () {
    final venue = parse(const [], stars: 4);
    expect(venue.starRating, 4);
    expect(venue.avgRating, 0);
    expect(parse(const []).starRating, isNull);
  });

  test('minStarRating is part of query equality and hasFilters', () {
    const a = VenueSearchQuery(minStarRating: 4);
    expect(a.hasFilters, isTrue);
    expect(a == const VenueSearchQuery(minStarRating: 4), isTrue);
    expect(a == const VenueSearchQuery(minStarRating: 3), isFalse);
    expect(a.copyWith(minStarRating: () => null).minStarRating, isNull);
  });
}
