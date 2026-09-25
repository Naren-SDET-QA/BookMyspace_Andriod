import 'package:bookmyspace/features/venue_sections/domain/venue_section.dart';
import 'package:flutter_test/flutter_test.dart';

VenueSection _section({
  Map<String, dynamic>? publishedConfig,
  Map<String, String> titleTranslations = const {'te': 'సౌకర్యాలు'},
  Map<String, String> contentTranslations = const {'te': 'ఉచిత పార్కింగ్'},
  String? icon = 'wifi',
  List<String> visibleSubsections = const ['parking', 'wifi'],
  Map<String, dynamic> config = const {'layout': 'grid'},
}) {
  return VenueSection(
    id: 'section-1',
    venueId: 'venue-1',
    sectionTypeId: 'type-1',
    type: const VenueSectionType(
      id: 'type-1',
      key: 'amenities',
      name: 'Amenities',
    ),
    title: 'Amenities',
    titleTranslations: titleTranslations,
    content: 'Free parking',
    contentTranslations: contentTranslations,
    icon: icon,
    visibleSubsections: visibleSubsections,
    config: config,
    publishedConfig: publishedConfig ??
        {
          'is_enabled': true,
          'title': 'Amenities',
          'title_i18n': {'te': 'సౌకర్యాలు'},
          'content': 'Free parking',
          'content_i18n': {'te': 'ఉచిత పార్కింగ్'},
          'icon': 'wifi',
          'display_order': 0,
          'visible_subsections': ['parking', 'wifi'],
          'config': {'layout': 'grid'},
        },
    publishedAt: DateTime(2026, 9, 13),
  );
}

void main() {
  test('matching draft and published snapshots have no pending changes', () {
    expect(_section().hasUnpublishedChanges, isFalse);
  });

  test('multilingual title and content changes remain unpublished', () {
    expect(
      _section(titleTranslations: const {'te': 'సౌకర్యాలు', 'hi': 'सुविधाएँ'})
          .hasUnpublishedChanges,
      isTrue,
    );
    expect(
      _section(contentTranslations: const {'te': 'వై-ఫై మరియు పార్కింగ్'})
          .hasUnpublishedChanges,
      isTrue,
    );
  });

  test('icon, config, and subsection order changes remain unpublished', () {
    expect(_section(icon: 'local_parking').hasUnpublishedChanges, isTrue);
    expect(
      _section(config: const {'layout': 'list'}).hasUnpublishedChanges,
      isTrue,
    );
    expect(
      _section(visibleSubsections: const ['wifi', 'parking'])
          .hasUnpublishedChanges,
      isTrue,
    );
  });

  test('published customer snapshots resolve multilingual content', () {
    final section = PublishedVenueSection.fromJson({
      'id': 'section-1',
      'section_key': 'amenities',
      'section_name': 'Amenities',
      'title': 'Amenities',
      'title_i18n': {'te': 'సౌకర్యాలు'},
      'content': 'Free parking',
      'content_i18n': {'te': 'ఉచిత పార్కింగ్'},
      'visible_subsections': ['parking'],
      'config': {'layout': 'grid'},
      'published_at': '2026-09-13T00:00:00Z',
    });

    expect(section.localizedTitle('te'), 'సౌకర్యాలు');
    expect(section.localizedContent('te'), 'ఉచిత పార్కింగ్');
    expect(section.localizedTitle('fr'), 'Amenities');
    expect(section.localizedContent('fr'), 'Free parking');
    expect(section.config['layout'], 'grid');
  });
}
