import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/venue_sections/domain/venue_section.dart';

void main() {
  test('venue section round-trips owner presentation metadata', () {
    final section = VenueSection.fromJson({
      'id': 'section-1',
      'venue_id': 'venue-1',
      'section_type_id': 'type-1',
      'type_key': 'amenities',
      'is_enabled': true,
      'title': 'Amenities',
      'title_i18n': {'hi': 'सुविधाएँ'},
      'content': 'Free parking and Wi-Fi',
      'content_i18n': {'hi': 'निःशुल्क पार्किंग और वाई-फाई'},
      'visible_subsections': ['parking'],
      'config': {
        'provider_setting': 'preserved',
      },
      'published_config': {
        'title': 'Amenities',
      },
      'published_at': '2026-09-13T00:00:00Z',
    });

    expect(section.isEnabled, isTrue);
    expect(section.isPublished, isTrue);
    expect(section.titleTranslations['hi'], 'सुविधाएँ');
    expect(section.config['provider_setting'], 'preserved');
    expect(section.visibleSubsections, contains('parking'));
  });
}
