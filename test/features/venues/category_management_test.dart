import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/venues/domain/listing_template.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';

void main() {
  test('category preserves management metadata through JSON mapping', () {
    const category = VenueCategory(
      id: 'category-1',
      slug: 'function-halls',
      name: 'Function Halls',
      icon: '🏛️',
      description: 'Spaces for celebrations',
      imageUrl: 'https://example.com/category.jpg',
      imagePath: 'categories/category-1/category.jpg',
      isActive: true,
      parentSection: 'venues',
      displayOrder: 3,
      supportedLanguages: ['en', 'te'],
      nameTranslations: {'te': 'ఫంక్షన్ హాళ్లు'},
      descriptionTranslations: {'te': 'వేడుకల కోసం స్థలాలు'},
    );

    final restored = VenueCategory.fromJson(category.toJson());

    expect(restored.id, category.id);
    expect(restored.slug, category.slug);
    expect(restored.description, category.description);
    expect(restored.imageUrl, category.imageUrl);
    expect(restored.imagePath, category.imagePath);
    expect(restored.displayOrder, category.displayOrder);
    expect(restored.supportedLanguages, category.supportedLanguages);
    expect(restored.nameTranslations, category.nameTranslations);
    expect(restored.descriptionTranslations, category.descriptionTranslations);
  });

  test('listing template overlay survives JSON mapping', () {
    const category = VenueCategory(
      id: 'category-1',
      slug: 'function-halls',
      name: 'Function Halls',
      listingConfig: ListingTemplateConfig(
        templateId: 'hall',
        ctaBook: 'Reserve Hall',
        published: false,
      ),
    );

    final restored = VenueCategory.fromJson(category.toJson());
    expect(restored.listingTemplate.ctaBook, 'Reserve Hall');
    expect(restored.listingTemplate.isPublished, isFalse);
  });

  test('subsection preserves hierarchy, status, and translations', () {
    const subsection = VenueSubsection(
      id: 'subsection-1',
      categoryId: 'category-1',
      slug: 'wedding-halls',
      name: 'Wedding Halls',
      description: 'Wedding venues',
      isActive: false,
      displayOrder: 2,
      supportedLanguages: ['en', 'te'],
      nameTranslations: {'te': 'వెడ్డింగ్ హాళ్లు'},
    );

    final restored = VenueSubsection.fromJson(subsection.toJson());

    expect(restored.categoryId, subsection.categoryId);
    expect(restored.isActive, isFalse);
    expect(restored.displayOrder, 2);
    expect(restored.nameTranslations['te'], 'వెడ్డింగ్ హాళ్లు');
  });

  test('copyWith can clear stored media before a replacement upload', () {
    const category = VenueCategory(
      id: 'category-1',
      slug: 'function-halls',
      name: 'Function Halls',
      imageUrl: 'https://example.com/old.jpg',
      imagePath: 'categories/category-1/old.jpg',
    );

    final cleared = category.copyWith(clearImage: true, clearImagePath: true);

    expect(cleared.imageUrl, isEmpty);
    expect(cleared.imagePath, isEmpty);
  });
}
