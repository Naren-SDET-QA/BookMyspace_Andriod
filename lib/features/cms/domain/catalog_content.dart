import 'package:flutter/foundation.dart';

import '../../home/presentation/home_category_catalog.dart';
import 'cms_icon.dart';
import 'cms_localized_text.dart';
import 'cms_media_ref.dart';
import 'facility_capabilities.dart';

/// Backend-editable discovery catalogue: Facility Type -> Section -> Subsection.
///
/// ## What this is for
///
/// `home_category_catalog.dart` hardcodes the whole discovery taxonomy in Dart
/// — five master sections with their titles, subtitles, emoji, `IconData`,
/// accent colours and remote artwork URLs, plus ~28 subsections. Changing any
/// of it currently needs a developer, a build and a store release.
///
/// This model is the backend-editable mirror of that structure. It is
/// **additive**: nothing reads it yet, `home_category_catalog.dart` is
/// untouched, and [defaults] is generated *from* that file so the two cannot
/// drift.
///
/// ## Storage
///
/// Serialized into `public.feature_flags.config` under the key
/// [catalogContentFlagKey], exactly as `home_appearance` and `nav_tabs`
/// already are. No new table: the catalogue is one admin-authored document,
/// which is what that column already holds for the other two.
///
/// Live *inventory* stays where it belongs — `venue_categories` and
/// `venue_subsections` remain the source of truth for which categories exist,
/// their slugs and their venue counts. This document only governs **how the
/// taxonomy is presented**: wording, artwork, icons, order and visibility.
/// [CatalogSection.searchAliases] is the join back to those rows.
///
/// ## Failure behaviour
///
/// Every parser here is total. Malformed input yields [defaults] or drops the
/// offending entry; nothing throws. That matches `HomeAppearance.fromJson`
/// and `NavTabsConfig.fromJson`, and it is what lets Home render offline, in
/// widget tests, and against a database that has never been written to.
const String catalogContentFlagKey = 'category_catalog';

/// One entry in the catalogue tree. Shared shape for all three levels.
@immutable
abstract class CatalogNode {
  const CatalogNode({
    required this.key,
    this.title = CmsLocalizedText.empty,
    this.description = CmsLocalizedText.empty,
    this.iconId = CmsIcon.fallbackId,
    this.emoji = '',
    this.media = CmsMediaRef.none,
    this.order = 0,
    this.enabled = true,
    this.capabilities,
    this.constraints,
  });

  /// Stable identifier. Never renamed by an editor — renaming would orphan
  /// every reference. Matches the corresponding id/slug in
  /// `home_category_catalog.dart`.
  final String key;

  final CmsLocalizedText title;
  final CmsLocalizedText description;

  /// Stable icon id resolved through [CmsIcon]. Never an `IconData`.
  final String iconId;

  /// Optional decorative emoji, as the shipped catalogue already uses.
  final String emoji;

  final CmsMediaRef media;
  final int order;
  final bool enabled;

  /// Capability configuration for this node. Null means "no capabilities set".
  final FacilityCapabilities? capabilities;

  /// Admin-defined constraints on owner-editable capabilities. Only meaningful
  /// on admin-authored nodes; owner overrides must respect these bounds.
  final CapabilityConstraints? constraints;

  /// Convenience for render sites.
  String titleFor(String languageCode, {String fallback = ''}) =>
      title.resolveOr(languageCode, fallback);

  String descriptionFor(String languageCode, {String fallback = ''}) =>
      description.resolveOr(languageCode, fallback);
}

/// Deepest level: one filter beneath a section (e.g. "Marriage Halls").
@immutable
class CatalogSubsection extends CatalogNode {
  const CatalogSubsection({
    required super.key,
    super.title = CmsLocalizedText.empty,
    super.description = CmsLocalizedText.empty,
    super.iconId = CmsIcon.fallbackId,
    super.emoji = '',
    super.media = CmsMediaRef.none,
    super.order = 0,
    super.enabled = true,
    super.capabilities,
    super.constraints,
    this.aliasSlugs = const [],
  });

  /// Additional `venue_categories.slug` values that resolve to this entry.
  /// Deployed data carries historical spellings; dropping them would orphan
  /// live categories.
  final List<String> aliasSlugs;

  CatalogSubsection copyWith({
    CmsLocalizedText? title,
    CmsLocalizedText? description,
    String? iconId,
    String? emoji,
    CmsMediaRef? media,
    int? order,
    bool? enabled,
    List<String>? aliasSlugs,
    FacilityCapabilities? capabilities,
    CapabilityConstraints? constraints,
  }) {
    return CatalogSubsection(
      key: key,
      title: title ?? this.title,
      description: description ?? this.description,
      iconId: iconId ?? this.iconId,
      emoji: emoji ?? this.emoji,
      media: media ?? this.media,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      aliasSlugs: aliasSlugs ?? this.aliasSlugs,
      capabilities: capabilities ?? this.capabilities,
      constraints: constraints ?? this.constraints,
    );
  }

  /// Returns `null` when [json] carries no usable key, so the caller can drop
  /// the entry instead of rendering a nameless row.
  static CatalogSubsection? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = _readKey(json['key']);
    if (key == null) return null;
    return CatalogSubsection(
      key: key,
      title: CmsLocalizedText.fromJson(json['title']),
      description: CmsLocalizedText.fromJson(json['description']),
      iconId: CmsIcon.normalize(json['icon']),
      emoji: _readEmoji(json['emoji']),
      media: CmsMediaRef.fromJson(json['media']),
      order: _readInt(json['order']) ?? 0,
      enabled: json['enabled'] != false,
      aliasSlugs: _readSlugList(json['alias_slugs']),
      capabilities: FacilityCapabilities.fromJson(json['capabilities']),
      constraints: CapabilityConstraints.fromJson(json['constraints']),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        if (title.isNotEmpty) 'title': title.toJson(),
        if (description.isNotEmpty) 'description': description.toJson(),
        'icon': iconId,
        if (emoji.isNotEmpty) 'emoji': emoji,
        if (media.isNotEmpty) 'media': media.toJson(),
        'order': order,
        'enabled': enabled,
        if (aliasSlugs.isNotEmpty) 'alias_slugs': aliasSlugs,
        if (capabilities != null && !capabilities!.isEmpty)
          'capabilities': capabilities!.toJson(),
        if (constraints != null && !constraints!.isEmpty)
          'constraints': constraints!.toJson(),
      };
}

/// Middle level: a master discovery section (e.g. "Function Halls").
@immutable
class CatalogSection extends CatalogNode {
  const CatalogSection({
    required super.key,
    super.title = CmsLocalizedText.empty,
    super.description = CmsLocalizedText.empty,
    super.iconId = CmsIcon.fallbackId,
    super.emoji = '',
    super.media = CmsMediaRef.none,
    super.order = 0,
    super.enabled = true,
    super.capabilities,
    super.constraints,
    this.displayTitle = CmsLocalizedText.empty,
    this.searchAliases = const [],
    this.subsections = const [],
  });

  /// Longer heading used where there is room ("Function Halls &
  /// Celebrations"). Falls back to [title] when unset.
  final CmsLocalizedText displayTitle;

  /// `venue_categories.slug` values that identify this section's master
  /// category. This is the join key back to live inventory.
  final List<String> searchAliases;

  final List<CatalogSubsection> subsections;

  /// Enabled subsections in admin order.
  List<CatalogSubsection> get visibleSubsections {
    final list = subsections.where((s) => s.enabled).toList()
      ..sort(_byOrderThenKey);
    return list;
  }

  String displayTitleFor(String languageCode, {String fallback = ''}) {
    final value = displayTitle.resolve(languageCode);
    if (value.trim().isNotEmpty) return value;
    return titleFor(languageCode, fallback: fallback);
  }

  CatalogSection copyWith({
    CmsLocalizedText? title,
    CmsLocalizedText? displayTitle,
    CmsLocalizedText? description,
    String? iconId,
    String? emoji,
    CmsMediaRef? media,
    int? order,
    bool? enabled,
    List<String>? searchAliases,
    List<CatalogSubsection>? subsections,
    FacilityCapabilities? capabilities,
    CapabilityConstraints? constraints,
  }) {
    return CatalogSection(
      key: key,
      title: title ?? this.title,
      displayTitle: displayTitle ?? this.displayTitle,
      description: description ?? this.description,
      iconId: iconId ?? this.iconId,
      emoji: emoji ?? this.emoji,
      media: media ?? this.media,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      searchAliases: searchAliases ?? this.searchAliases,
      subsections: subsections ?? this.subsections,
      capabilities: capabilities ?? this.capabilities,
      constraints: constraints ?? this.constraints,
    );
  }

  static CatalogSection? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = _readKey(json['key']);
    if (key == null) return null;
    return CatalogSection(
      key: key,
      title: CmsLocalizedText.fromJson(json['title']),
      displayTitle: CmsLocalizedText.fromJson(json['display_title']),
      description: CmsLocalizedText.fromJson(json['description']),
      iconId: CmsIcon.normalize(json['icon']),
      emoji: _readEmoji(json['emoji']),
      media: CmsMediaRef.fromJson(json['media']),
      order: _readInt(json['order']) ?? 0,
      enabled: json['enabled'] != false,
      searchAliases: _readSlugList(json['search_aliases']),
      subsections:
          _readNodeList(json['subsections'], CatalogSubsection.fromJson),
      capabilities: FacilityCapabilities.fromJson(json['capabilities']),
      constraints: CapabilityConstraints.fromJson(json['constraints']),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        if (title.isNotEmpty) 'title': title.toJson(),
        if (displayTitle.isNotEmpty) 'display_title': displayTitle.toJson(),
        if (description.isNotEmpty) 'description': description.toJson(),
        'icon': iconId,
        if (emoji.isNotEmpty) 'emoji': emoji,
        if (media.isNotEmpty) 'media': media.toJson(),
        'order': order,
        'enabled': enabled,
        if (searchAliases.isNotEmpty) 'search_aliases': searchAliases,
        'subsections': [for (final s in subsections) s.toJson()],
        if (capabilities != null && !capabilities!.isEmpty)
          'capabilities': capabilities!.toJson(),
        if (constraints != null && !constraints!.isEmpty)
          'constraints': constraints!.toJson(),
      };
}

/// Top level: a family of sections (e.g. "Venues", "Sports").
///
/// Today each facility type holds exactly one section, mirroring the deployed
/// `venue_categories.parent_section` values. The level exists so a second
/// section can be added under a type without a schema change — that is the
/// extension point this batch is preparing.
@immutable
class CatalogFacilityType extends CatalogNode {
  const CatalogFacilityType({
    required super.key,
    super.title = CmsLocalizedText.empty,
    super.description = CmsLocalizedText.empty,
    super.iconId = CmsIcon.fallbackId,
    super.emoji = '',
    super.media = CmsMediaRef.none,
    super.order = 0,
    super.enabled = true,
    super.capabilities,
    super.constraints,
    this.sections = const [],
  });

  final List<CatalogSection> sections;

  /// Enabled sections in admin order.
  List<CatalogSection> get visibleSections {
    final list = sections.where((s) => s.enabled).toList()
      ..sort(_byOrderThenKey);
    return list;
  }

  CatalogFacilityType copyWith({
    CmsLocalizedText? title,
    CmsLocalizedText? description,
    String? iconId,
    String? emoji,
    CmsMediaRef? media,
    int? order,
    bool? enabled,
    List<CatalogSection>? sections,
    FacilityCapabilities? capabilities,
    CapabilityConstraints? constraints,
  }) {
    return CatalogFacilityType(
      key: key,
      title: title ?? this.title,
      description: description ?? this.description,
      iconId: iconId ?? this.iconId,
      emoji: emoji ?? this.emoji,
      media: media ?? this.media,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      sections: sections ?? this.sections,
      capabilities: capabilities ?? this.capabilities,
      constraints: constraints ?? this.constraints,
    );
  }

  static CatalogFacilityType? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = _readKey(json['key']);
    if (key == null) return null;
    return CatalogFacilityType(
      key: key,
      title: CmsLocalizedText.fromJson(json['title']),
      description: CmsLocalizedText.fromJson(json['description']),
      iconId: CmsIcon.normalize(json['icon']),
      emoji: _readEmoji(json['emoji']),
      media: CmsMediaRef.fromJson(json['media']),
      order: _readInt(json['order']) ?? 0,
      enabled: json['enabled'] != false,
      sections: _readNodeList(json['sections'], CatalogSection.fromJson),
      capabilities: FacilityCapabilities.fromJson(json['capabilities']),
      constraints: CapabilityConstraints.fromJson(json['constraints']),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        if (title.isNotEmpty) 'title': title.toJson(),
        if (description.isNotEmpty) 'description': description.toJson(),
        'icon': iconId,
        if (emoji.isNotEmpty) 'emoji': emoji,
        if (media.isNotEmpty) 'media': media.toJson(),
        'order': order,
        'enabled': enabled,
        'sections': [for (final s in sections) s.toJson()],
        if (capabilities != null && !capabilities!.isEmpty)
          'capabilities': capabilities!.toJson(),
        if (constraints != null && !constraints!.isEmpty)
          'constraints': constraints!.toJson(),
      };
}

/// The whole catalogue document.
@immutable
class CatalogContent {
  const CatalogContent(this.facilityTypes);

  final List<CatalogFacilityType> facilityTypes;

  /// Enabled facility types in admin order.
  List<CatalogFacilityType> get visible {
    final list = facilityTypes.where((f) => f.enabled).toList()
      ..sort(_byOrderThenKey);
    return list;
  }

  CatalogFacilityType? facilityTypeFor(String key) {
    for (final type in facilityTypes) {
      if (type.key == key) return type;
    }
    return null;
  }

  /// Depth-first lookup of a section by key, across all facility types.
  CatalogSection? sectionFor(String key) {
    for (final type in facilityTypes) {
      for (final section in type.sections) {
        if (section.key == key) return section;
      }
    }
    return null;
  }

  /// Reads a stored document.
  ///
  /// Returns [defaults] when the payload is absent, not an object, carries no
  /// `facility_types` array, or yields no usable entry — the same
  /// "never render nothing" contract as `HomeAppearance.fromJson`. A facility
  /// type present in [defaults] but missing from the payload is re-added, so
  /// shipping a new section never makes it silently vanish for admins who
  /// saved the catalogue before it existed.
  factory CatalogContent.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final raw = json['facility_types'];
    if (raw is! List) return defaults;

    final parsed = _readNodeList(raw, CatalogFacilityType.fromJson);
    if (parsed.isEmpty) return defaults;

    final seen = {for (final type in parsed) type.key};
    final merged = <CatalogFacilityType>[...parsed];
    for (final fallback in defaults.facilityTypes) {
      if (!seen.contains(fallback.key)) merged.add(fallback);
    }
    return CatalogContent(merged);
  }

  Map<String, dynamic> toJson() => {
        'facility_types': [for (final type in facilityTypes) type.toJson()],
      };

  // -------------------------------------------------------------------------
  // Editing
  //
  // Every mutation returns a new document. Nothing is edited in place, so an
  // admin screen can hold a draft, compare it to what is published, and throw
  // it away without having corrupted anything.
  // -------------------------------------------------------------------------

  /// True when [key] is one of the facility types generated from
  /// `home_category_catalog.dart`.
  ///
  /// Shipped types can be **hidden but not deleted**: [CatalogContent.fromJson]
  /// re-adds any default the payload omits, so a delete would silently come
  /// back on the next load. An editor should offer "disable" for these and
  /// reserve delete for types an admin created.
  static bool isShippedFacilityType(String key) =>
      defaults.facilityTypeFor(key) != null;

  CatalogContent _withTypes(List<CatalogFacilityType> types) =>
      CatalogContent(List.unmodifiable(types));

  /// Inserts [type], or replaces the existing entry with the same key in place
  /// (preserving its position in the list).
  CatalogContent upsertFacilityType(CatalogFacilityType type) {
    final next = <CatalogFacilityType>[];
    var replaced = false;
    for (final existing in facilityTypes) {
      if (existing.key == type.key) {
        next.add(type);
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) next.add(type);
    return _withTypes(next);
  }

  /// Removes a facility type. A no-op for shipped types, which
  /// [isShippedFacilityType] explains.
  CatalogContent removeFacilityType(String key) {
    if (isShippedFacilityType(key)) return this;
    return _withTypes(
      facilityTypes.where((type) => type.key != key).toList(),
    );
  }

  /// Inserts or replaces a section under [typeKey]. No-op when the type is
  /// unknown, so a stale editor reference cannot create an orphan.
  CatalogContent upsertSection(String typeKey, CatalogSection section) {
    final type = facilityTypeFor(typeKey);
    if (type == null) return this;

    final next = <CatalogSection>[];
    var replaced = false;
    for (final existing in type.sections) {
      if (existing.key == section.key) {
        next.add(section);
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) next.add(section);
    return upsertFacilityType(type.copyWith(sections: next));
  }

  CatalogContent removeSection(String typeKey, String sectionKey) {
    final type = facilityTypeFor(typeKey);
    if (type == null) return this;
    return upsertFacilityType(
      type.copyWith(
        sections: type.sections.where((s) => s.key != sectionKey).toList(),
      ),
    );
  }

  /// Inserts or replaces a subsection. No-op when the type or section is
  /// unknown.
  CatalogContent upsertSubsection(
    String typeKey,
    String sectionKey,
    CatalogSubsection subsection,
  ) {
    final type = facilityTypeFor(typeKey);
    if (type == null) return this;
    CatalogSection? section;
    for (final candidate in type.sections) {
      if (candidate.key == sectionKey) section = candidate;
    }
    if (section == null) return this;

    final next = <CatalogSubsection>[];
    var replaced = false;
    for (final existing in section.subsections) {
      if (existing.key == subsection.key) {
        next.add(subsection);
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) next.add(subsection);
    return upsertSection(typeKey, section.copyWith(subsections: next));
  }

  CatalogContent removeSubsection(
    String typeKey,
    String sectionKey,
    String subsectionKey,
  ) {
    final type = facilityTypeFor(typeKey);
    if (type == null) return this;
    for (final section in type.sections) {
      if (section.key != sectionKey) continue;
      return upsertSection(
        typeKey,
        section.copyWith(
          subsections:
              section.subsections.where((s) => s.key != subsectionKey).toList(),
        ),
      );
    }
    return this;
  }

  /// The facility type that owns [sectionKey], or `null`.
  CatalogFacilityType? facilityTypeOfSection(String sectionKey) {
    for (final type in facilityTypes) {
      for (final section in type.sections) {
        if (section.key == sectionKey) return type;
      }
    }
    return null;
  }

  /// True when [key] is already used at any level. Keys are the stable
  /// identity of a node, so an editor must refuse to mint a duplicate.
  bool containsKey(String key) {
    for (final type in facilityTypes) {
      if (type.key == key) return true;
      for (final section in type.sections) {
        if (section.key == key) return true;
        for (final sub in section.subsections) {
          if (sub.key == key) return true;
        }
      }
    }
    return false;
  }

  /// The shipped catalogue, generated from `home_category_catalog.dart`.
  ///
  /// Derived rather than retyped so the fallback cannot drift from the
  /// hardcoded catalogue it is meant to mirror. `MainHomeSection` stays the
  /// single source of truth until a later batch migrates render sites over.
  static final CatalogContent defaults = _buildDefaults();
}

// ---------------------------------------------------------------------------
// Defaults derived from the shipped hardcoded catalogue
// ---------------------------------------------------------------------------

/// Icon ids for the five shipped sections.
///
/// Each id resolves through [CmsIcon] to the *same* glyph
/// `MainHomeSection.iconData` returns today, so the default document renders
/// identically to the hardcoded catalogue.
const Map<String, String> _sectionIconIds = {
  'function_halls': 'hall',
  'sports_turfs': 'turf',
  'pg_hostels': 'home',
  'institutes_classes': 'school',
  'lodge_rooms': 'hotel',
};

/// Icon ids for the shipped subsections, keyed by slug. Anything absent falls
/// back to [CmsIcon.fallbackId]; the emoji still carries the visual identity.
const Map<String, String> _subsectionIconIds = {
  'marriage_hall': 'ring',
  'banquet_hall': 'banquet',
  'convention_center': 'convention',
  'party_hall': 'party',
  'engagement_hall': 'celebration',
  'reception_hall': 'toast',
  'premium_hall': 'crown',
  'outdoor_venue': 'garden',
  'sports': 'turf',
  'gym': 'gym',
  'coworking': 'desk',
  'photography_studio': 'camera',
  'gents_pg': 'person',
  'ladies_pg': 'person',
  'student_hostel': 'backpack',
  'coliving': 'sofa',
  'coaching': 'book',
  'tuition': 'pencil',
  'computer': 'computer',
  'dance': 'music',
  'hotel': 'hotel',
  'hourly_room': 'clock',
  'lodge': 'bed',
  'resort': 'palm',
};

CatalogContent _buildDefaults() {
  final types = <CatalogFacilityType>[];
  var typeOrder = 10;

  for (final section in MainHomeSection.discoveryOrder) {
    // The deployed `venue_categories.parent_section` value for this section.
    // First alias is the canonical one; the rest are historical spellings.
    final facilityKey = section.parentSectionAliases.isEmpty
        ? section.id
        : section.parentSectionAliases.first;

    final subsections = <CatalogSubsection>[];
    var subOrder = 10;
    for (final sub in section.subSections) {
      subsections.add(
        CatalogSubsection(
          key: sub.slug,
          title: CmsLocalizedText(base: sub.label),
          iconId: _subsectionIconIds[sub.slug] ?? CmsIcon.fallbackId,
          emoji: sub.emoji,
          order: subOrder,
          aliasSlugs: sub.aliasSlugs,
        ),
      );
      subOrder += 10;
    }

    final catalogSection = CatalogSection(
      key: section.id,
      title: CmsLocalizedText(base: section.title),
      displayTitle: CmsLocalizedText(base: section.displayTitle),
      description: CmsLocalizedText(base: section.subtitle),
      iconId: _sectionIconIds[section.id] ?? CmsIcon.fallbackId,
      emoji: section.emoji,
      media: CmsMediaRef.fromJson(section.fallbackImageUrl),
      order: typeOrder,
      searchAliases: section.searchAliases,
      subsections: subsections,
    );

    // One section per facility type today. The type reuses the section's
    // short title rather than inventing new wording, so the default document
    // introduces no copy that a product owner never approved.
    types.add(
      CatalogFacilityType(
        key: facilityKey,
        title: CmsLocalizedText(base: section.title),
        iconId: catalogSection.iconId,
        emoji: section.emoji,
        order: typeOrder,
        sections: [catalogSection],
      ),
    );
    typeOrder += 10;
  }

  return CatalogContent(types);
}

// ---------------------------------------------------------------------------
// Shared parsing helpers
// ---------------------------------------------------------------------------

/// Stable keys are lowercase slugs. Anything else is rejected so a malformed
/// key can never become a lookup that silently never matches.
final RegExp _keyPattern = RegExp(r'^[a-z0-9]+(?:[-_][a-z0-9]+)*$');

String? _readKey(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim().toLowerCase();
  if (trimmed.isEmpty || trimmed.length > 64) return null;
  return _keyPattern.hasMatch(trimmed) ? trimmed : null;
}

/// Emoji are decorative. Cap the length so a pasted paragraph cannot end up
/// rendered as an icon.
String _readEmoji(Object? value) {
  if (value is! String) return '';
  final trimmed = value.trim();
  // Counted in runes rather than grapheme clusters so this stays free of
  // package:characters, which only package:flutter/widgets.dart re-exports.
  // A ZWJ emoji is several runes, hence the loose ceiling.
  return trimmed.runes.length <= 8 ? trimmed : '';
}

int? _readInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<String> _readSlugList(Object? value) {
  if (value is! List) return const [];
  final out = <String>[];
  for (final entry in value) {
    final slug = _readKey(entry);
    if (slug != null && !out.contains(slug)) out.add(slug);
  }
  return List.unmodifiable(out);
}

/// Parses a list of nodes, dropping entries the parser rejects and any entry
/// whose key duplicates an earlier one. First occurrence wins, so a duplicated
/// key degrades to "one entry" rather than to a doubled row.
List<T> _readNodeList<T extends CatalogNode>(
  Object? value,
  T? Function(Object?) parse,
) {
  if (value is! List) return <T>[];
  final out = <T>[];
  final seen = <String>{};
  for (final entry in value) {
    final node = parse(entry);
    if (node == null) continue;
    if (!seen.add(node.key)) continue;
    out.add(node);
  }
  return List.unmodifiable(out);
}

int _byOrderThenKey(CatalogNode a, CatalogNode b) {
  final byOrder = a.order.compareTo(b.order);
  // Tie-break on key so a duplicated `order` still yields a stable list
  // instead of one that reshuffles between rebuilds.
  return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
}
