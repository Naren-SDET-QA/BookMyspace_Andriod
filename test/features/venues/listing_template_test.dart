import 'package:bookmyspace/features/venues/domain/listing_template.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListingTemplateConfig', () {
    test('resolves halls, hotels, temples, sports, studios, pg, education', () {
      expect(
        ListingTemplateConfig.defaultsFor(slug: 'marriage_hall').templateId,
        'hall',
      );
      expect(
        ListingTemplateConfig.defaultsFor(slug: 'hotel_stay').templateId,
        'hotel',
      );
      expect(
        ListingTemplateConfig.defaultsFor(slug: 'temple').templateId,
        'temple',
      );
      expect(
        ListingTemplateConfig.defaultsFor(slug: 'sports_ground').templateId,
        'sports',
      );
      expect(
        ListingTemplateConfig.defaultsFor(slug: 'photography_studio')
            .templateId,
        'studio',
      );
      expect(
        ListingTemplateConfig.defaultsFor(slug: 'gents_pg').templateId,
        'pg',
      );
      expect(
        ListingTemplateConfig.defaultsFor(slug: 'coaching').templateId,
        'education',
      );
    });

    test('admin overlay replaces CTA and keeps default fields when empty', () {
      final stored = ListingTemplateConfig(
        templateId: 'hall',
        ctaBook: 'Reserve Hall',
        published: false,
      );
      final resolved = ListingTemplateConfig.resolve(
        slug: 'function_hall',
        stored: stored,
      );
      expect(resolved.ctaBook, 'Reserve Hall');
      expect(resolved.published, isFalse);
      expect(resolved.fields, isNotEmpty);
      expect(resolved.fields.any((field) => field.key == 'guests'), isTrue);
    });

    test('round-trips through venue category metadata', () {
      const category = VenueCategory(
        id: 'c1',
        slug: 'temple',
        name: 'Temples',
        listingConfig: ListingTemplateConfig(
          templateId: 'temple',
          ctaBook: 'Book Darshan',
          published: true,
        ),
      );
      final restored = VenueCategory.fromJson(category.toJson());
      expect(restored.listingTemplate.templateId, 'temple');
      expect(restored.listingTemplate.ctaBook, 'Book Darshan');
      expect(restored.toJson()['metadata']['listing']['template'], 'temple');
    });
  });

  group('Venue listing extras', () {
    test('hides discount unless original price is higher', () {
      const venue = Venue(
        id: 'v',
        name: 'V',
        latitude: 0,
        longitude: 0,
        price: 1000,
        originalPrice: 1000,
      );
      expect(venue.hasDiscount, isFalse);
      expect(
        venue.copyWith(originalPrice: 1500).hasDiscount,
        isTrue,
      );
    });

    test('reads cancellation summary from live jsonb', () {
      final venue = Venue.fromJson({
        'id': 'v',
        'name': 'Hall',
        'latitude': 0,
        'longitude': 0,
        'cancellation_policy': {'summary': 'Free cancel 48h before'},
        'rules': 'No alcohol',
      });
      expect(venue.cancellationSummary, 'Free cancel 48h before');
      expect(venue.rules, 'No alcohol');
    });
  });
}
