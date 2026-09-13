/// Domain models for Owner-configurable, plug-and-play venue page sections.
///
/// `VenueSectionType` is the Admin-managed global catalog of section kinds
/// (About, Amenities, Gallery, Policies, FAQ, Nearby, Custom). `VenueSection`
/// is one venue's instance of a type: the Owner-editable draft. Customer
/// surfaces never see this draft model -- they read `PublishedVenueSection`,
/// which comes back from the `list_published_venue_sections` RPC and only
/// ever reflects the venue's last published snapshot.
library;

/// One entry in a section type's admin-defined list of optional subsections
/// (e.g. Amenities -> Parking, Wi-Fi, Catering).
class VenueSubsectionOption {
  const VenueSubsectionOption({required this.key, required this.label});

  final String key;
  final String label;

  factory VenueSubsectionOption.fromJson(Map<String, dynamic> json) {
    return VenueSubsectionOption(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? (json['key'] as String? ?? ''),
    );
  }
}

/// Admin-managed catalog entry describing an optional page section an Owner
/// may add to their own venue. Global, platform-wide configuration -- never
/// Owner-writable.
class VenueSectionType {
  const VenueSectionType({
    required this.id,
    required this.key,
    required this.name,
    this.description = '',
    this.icon,
    this.allowsMultiple = false,
    this.availableSubsections = const [],
    this.editableFields = const {},
    this.isActive = true,
    this.displayOrder = 0,
  });

  final String id;
  final String key;
  final String name;
  final String description;
  final String? icon;
  final bool allowsMultiple;
  final List<VenueSubsectionOption> availableSubsections;
  final Map<String, dynamic> editableFields;
  final bool isActive;
  final int displayOrder;

  bool get supportsTitle => editableFields['title'] != false;
  bool get supportsContent => editableFields['content'] != false;
  bool get supportsImage => editableFields['image'] == true;
  bool get supportsSubsections =>
      editableFields['subsections'] == true && availableSubsections.isNotEmpty;

  factory VenueSectionType.fromJson(Map<String, dynamic> json) {
    final subsections = <VenueSubsectionOption>[];
    final rawSubsections = json['available_subsections'];
    if (rawSubsections is List) {
      for (final item in rawSubsections) {
        if (item is Map<String, dynamic>) {
          subsections.add(VenueSubsectionOption.fromJson(item));
        }
      }
    }
    final rawFields = json['editable_fields'];
    return VenueSectionType(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String?,
      allowsMultiple: json['allows_multiple'] as bool? ?? false,
      availableSubsections: subsections,
      editableFields:
          rawFields is Map ? Map<String, dynamic>.from(rawFields) : const {},
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One venue's draft instance of a section type. Owner-editable via RLS
/// scoped to the owning organisation; the server is the sole authority on
/// whether a write is accepted.
class VenueSection {
  const VenueSection({
    required this.id,
    required this.venueId,
    required this.sectionTypeId,
    required this.type,
    this.isEnabled = true,
    this.title = '',
    this.titleTranslations = const {},
    this.content = '',
    this.contentTranslations = const {},
    this.imageUrl = '',
    this.imagePath = '',
    this.icon,
    this.displayOrder = 0,
    this.visibleSubsections = const [],
    this.config = const {},
    this.publishedConfig,
    this.publishedAt,
  });

  final String id;
  final String venueId;
  final String sectionTypeId;
  final VenueSectionType type;
  final bool isEnabled;
  final String title;
  final Map<String, String> titleTranslations;
  final String content;
  final Map<String, String> contentTranslations;
  final String imageUrl;
  final String imagePath;
  final String? icon;
  final int displayOrder;
  final List<String> visibleSubsections;
  final Map<String, dynamic> config;

  /// Snapshot of the fields above as they were the last time this section
  /// was published. Null means this section has never been published.
  final Map<String, dynamic>? publishedConfig;
  final DateTime? publishedAt;

  bool get isPublished => publishedConfig != null;

  /// True when the current draft differs from what customers can currently
  /// see (or nothing has ever been published yet).
  bool get hasUnpublishedChanges {
    final published = publishedConfig;
    if (published == null) return true;
    return published['is_enabled'] != isEnabled ||
        (published['title'] as String? ?? '') != title ||
        !_deepEquals(published['title_i18n'] ?? const {}, titleTranslations) ||
        (published['content'] as String? ?? '') != content ||
        !_deepEquals(
          published['content_i18n'] ?? const {},
          contentTranslations,
        ) ||
        (published['image_url'] as String? ?? '') != imageUrl ||
        (published['icon'] as String?) != icon ||
        (published['display_order'] as num?)?.toInt() != displayOrder ||
        !_orderedListEquals(
          (published['visible_subsections'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          visibleSubsections,
        ) ||
        !_deepEquals(published['config'] ?? const {}, config);
  }

  factory VenueSection.fromJson(Map<String, dynamic> json) {
    final typeJson = json['venue_section_types'];
    final type = typeJson is Map<String, dynamic>
        ? VenueSectionType.fromJson(typeJson)
        : VenueSectionType(
            id: json['section_type_id'] as String? ?? '',
            key: json['type_key'] as String? ?? '',
            name: json['type_key'] as String? ?? 'Section',
          );
    return VenueSection(
      id: json['id'] as String? ?? '',
      venueId: json['venue_id'] as String? ?? '',
      sectionTypeId: json['section_type_id'] as String? ?? '',
      type: type,
      isEnabled: json['is_enabled'] as bool? ?? true,
      title: json['title'] as String? ?? '',
      titleTranslations: _stringMap(json['title_i18n']),
      content: json['content'] as String? ?? '',
      contentTranslations: _stringMap(json['content_i18n']),
      imageUrl: json['image_url'] as String? ?? '',
      imagePath: json['image_path'] as String? ?? '',
      icon: json['icon'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      visibleSubsections: (json['visible_subsections'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
      publishedConfig: json['published_config'] is Map
          ? Map<String, dynamic>.from(json['published_config'] as Map)
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
    );
  }

  VenueSection copyWith({
    bool? isEnabled,
    String? title,
    Map<String, String>? titleTranslations,
    String? content,
    Map<String, String>? contentTranslations,
    String? imageUrl,
    String? imagePath,
    bool clearImage = false,
    String? icon,
    int? displayOrder,
    List<String>? visibleSubsections,
    Map<String, dynamic>? config,
  }) {
    return VenueSection(
      id: id,
      venueId: venueId,
      sectionTypeId: sectionTypeId,
      type: type,
      isEnabled: isEnabled ?? this.isEnabled,
      title: title ?? this.title,
      titleTranslations: titleTranslations ?? this.titleTranslations,
      content: content ?? this.content,
      contentTranslations: contentTranslations ?? this.contentTranslations,
      imageUrl: clearImage ? '' : (imageUrl ?? this.imageUrl),
      imagePath: clearImage ? '' : (imagePath ?? this.imagePath),
      icon: icon ?? this.icon,
      displayOrder: displayOrder ?? this.displayOrder,
      visibleSubsections: visibleSubsections ?? this.visibleSubsections,
      config: config ?? this.config,
      publishedConfig: publishedConfig,
      publishedAt: publishedAt,
    );
  }
}

/// A single published, customer-visible section, as returned by
/// `list_published_venue_sections`. This is the ONLY section content
/// customer surfaces are allowed to read.
class PublishedVenueSection {
  const PublishedVenueSection({
    required this.id,
    required this.sectionKey,
    required this.sectionName,
    this.sectionIcon,
    this.title = '',
    this.titleTranslations = const {},
    this.content = '',
    this.contentTranslations = const {},
    this.imageUrl = '',
    this.displayOrder = 0,
    this.visibleSubsections = const [],
    this.config = const {},
    this.publishedAt,
  });

  final String id;
  final String sectionKey;
  final String sectionName;
  final String? sectionIcon;
  final String title;
  final Map<String, String> titleTranslations;
  final String content;
  final Map<String, String> contentTranslations;
  final String imageUrl;
  final int displayOrder;
  final List<String> visibleSubsections;
  final Map<String, dynamic> config;
  final DateTime? publishedAt;

  /// Resolves title/content for [languageCode], falling back to the
  /// venue-owner's default text when no translation was published for that
  /// language. Mirrors the existing admin-module localization convention
  /// used by _VenueModuleSections in venue_details_screen.dart.
  String localizedTitle(String languageCode) =>
      titleTranslations[languageCode]?.trim().isNotEmpty == true
          ? titleTranslations[languageCode]!.trim()
          : title;

  String localizedContent(String languageCode) =>
      contentTranslations[languageCode]?.trim().isNotEmpty == true
          ? contentTranslations[languageCode]!.trim()
          : content;

  factory PublishedVenueSection.fromJson(Map<String, dynamic> json) {
    return PublishedVenueSection(
      id: json['id'] as String? ?? '',
      sectionKey: json['section_key'] as String? ?? '',
      sectionName: json['section_name'] as String? ?? '',
      sectionIcon: json['section_icon'] as String?,
      title: json['title'] as String? ?? '',
      titleTranslations: _stringMap(json['title_i18n']),
      content: json['content'] as String? ?? '',
      contentTranslations: _stringMap(json['content_i18n']),
      imageUrl: json['image_url'] as String? ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      visibleSubsections: (json['visible_subsections'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      config: json['config'] is Map
          ? Map<String, dynamic>.from(json['config'] as Map)
          : const {},
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
    );
  }
}

Map<String, String> _stringMap(dynamic value) {
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), v.toString()));
  }
  return const {};
}

bool _orderedListEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _deepEquals(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
