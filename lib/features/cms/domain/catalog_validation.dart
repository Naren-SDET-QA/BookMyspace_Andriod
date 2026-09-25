import 'package:flutter/foundation.dart';

import 'catalog_content.dart';
import 'cms_icon.dart';
import 'cms_localized_text.dart';
import 'cms_media_ref.dart';
import 'facility_capabilities.dart';

/// How serious a validation finding is.
///
/// [error] blocks publishing. [warning] does not: it flags something an admin
/// probably did not mean, but which the app renders safely anyway. Blocking on
/// warnings would make the editor unusable mid-edit, when a half-finished
/// section legitimately has no artwork yet.
enum CatalogIssueLevel { error, warning }

/// One validation finding, addressed to a non-technical admin.
@immutable
class CatalogIssue {
  const CatalogIssue({
    required this.level,
    required this.message,
    this.nodeKey = '',
    this.field = '',
  });

  final CatalogIssueLevel level;

  /// Plain-language text shown directly in the editor. No error codes.
  final String message;

  /// Key of the offending node, so the editor can jump to it.
  final String nodeKey;

  /// Field name within that node (`title`, `icon`, `media`, ...).
  final String field;

  bool get isError => level == CatalogIssueLevel.error;

  @override
  String toString() => '[$level] $nodeKey.$field: $message';
}

/// Field- and document-level validation for the discovery catalogue.
///
/// Two jobs, deliberately separated:
///
/// * The `field*` methods validate one input as an admin types, returning a
///   message or `null`. They are what `TextFormField.validator` calls.
/// * [validate] checks the whole document before publishing, catching things
///   no single field can see - an empty catalogue, a duplicate key, a section
///   with no visible subsections.
///
/// This is the **client** half. The database validates independently
/// (`validate_feature_flag_config`), and the model's parsers drop anything
/// malformed on read. An admin who gets past this layer still cannot corrupt
/// the app; this exists so they get a useful message instead of a rejection.
///
/// ## On markup and scripts
///
/// Every string here is rendered through Flutter `Text` widgets, never as
/// HTML and never evaluated, so tags and scripts in content are inert by
/// construction rather than by sanitising. What this layer does reject is
/// control characters, which can reorder or hide rendered text, and
/// over-long input. Media is restricted to absolute `http(s)` URLs by
/// [CmsMediaRef], and icons to ids already compiled into the app by
/// [CmsIcon] - so neither can introduce a resource the app did not ship with.
class CatalogValidator {
  const CatalogValidator._();

  static const int maxTitleLength = 80;
  static const int maxDescriptionLength = 200;
  static const int maxOrder = 9999;
  static const int maxKeyLength = 64;

  /// Lowercase slug. Matches the model's own key pattern and the `slug` check
  /// constraint on `venue_subsections`, so a key an admin mints here is
  /// already valid everywhere it might later be stored.
  static final RegExp keyPattern = RegExp(r'^[a-z0-9]+(?:[-_][a-z0-9]+)*$');

  /// C0/C1 control characters, plus the bidirectional overrides that can make
  /// rendered text read differently from what is actually stored.
  static final RegExp _controlChars =
      RegExp(r'[\x00-\x1F\x7F-\x9F\u202A-\u202E\u2066-\u2069]');

  /// A locale override is optional, but when present it must be a normal
  /// language tag and must obey the same content limits as the default text.
  /// Keeping this generic means new app locales can be added without adding
  /// facility-specific language combinations here.
  static final RegExp _languageCode = RegExp(r'^[a-z]{2,3}(?:-[a-z]{2,4})?$');

  /// Validates a stable key. [existing] is the document being edited;
  /// [currentKey] is the key being renamed away from, if any.
  static String? fieldKey(
    String? value, {
    CatalogContent? existing,
    String currentKey = '',
  }) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Give this a short id, for example marriage_hall.';
    if (raw.length > maxKeyLength) {
      return 'Ids must be $maxKeyLength characters or fewer.';
    }
    if (raw != raw.toLowerCase()) {
      return 'Use lowercase only, for example marriage_hall.';
    }
    if (!keyPattern.hasMatch(raw)) {
      return 'Use lowercase letters, numbers and underscores only - no spaces.';
    }
    if (existing != null && raw != currentKey && existing.containsKey(raw)) {
      return 'That id is already used somewhere in this catalogue.';
    }
    return null;
  }

  /// Validates the base title. Required: a node with no title renders as a
  /// blank row a customer cannot identify.
  static String? fieldTitle(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Enter a title.';
    if (raw.length > maxTitleLength) {
      return 'Titles must be $maxTitleLength characters or fewer.';
    }
    if (_controlChars.hasMatch(raw)) {
      return 'Remove hidden or special characters from this title.';
    }
    return null;
  }

  /// Validates a translated title. Unlike the base title this may be empty -
  /// clearing it falls back to the base text.
  static String? fieldTranslation(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    if (raw.length > maxTitleLength) {
      return 'Translations must be $maxTitleLength characters or fewer.';
    }
    if (_controlChars.hasMatch(raw)) {
      return 'Remove hidden or special characters from this translation.';
    }
    return null;
  }

  static String? fieldDescription(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    if (raw.length > maxDescriptionLength) {
      return 'Descriptions must be $maxDescriptionLength characters or fewer.';
    }
    if (_controlChars.hasMatch(raw)) {
      return 'Remove hidden or special characters from this description.';
    }
    return null;
  }

  static String? fieldOrder(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Enter a position number.';
    final parsed = int.tryParse(raw);
    if (parsed == null) return 'Position must be a whole number.';
    if (parsed < 0) return 'Position cannot be negative.';
    if (parsed > maxOrder) return 'Position must be $maxOrder or less.';
    return null;
  }

  /// Validates an image URL. Empty is allowed - the app falls back to its
  /// built-in artwork.
  static String? fieldMediaUrl(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    if (!CmsMediaRef.isUsableUrl(raw)) {
      return 'Enter a full image address starting with https://';
    }
    return null;
  }

  static String? fieldIcon(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!CmsIcon.isKnown(value.trim())) {
      return 'Pick an icon from the list.';
    }
    return null;
  }

  /// Whole-document checks run before publishing.
  static List<CatalogIssue> validate(CatalogContent content) {
    final issues = <CatalogIssue>[];

    if (content.visible.isEmpty) {
      issues.add(const CatalogIssue(
        level: CatalogIssueLevel.error,
        message: 'Turn on at least one facility type before publishing. '
            'With none visible, customers would see the built-in catalogue '
            'instead of yours.',
      ));
    }

    // Ids are unique per *kind*, not across the whole document. The three
    // levels are separate namespaces: a facility type key is a deployed
    // `venue_categories.parent_section` value, a subsection key is a
    // `venue_categories.slug`. The shipped catalogue legitimately uses the
    // same string in both - `sports` is a parent section *and* a category
    // slug - and neither lookup can confuse them, because
    // `facilityTypeFor` only reads type keys and subsection resolution is
    // scoped to its parent. Requiring one global set would reject the
    // shipped catalogue itself.
    final seenTypeKeys = <String>{};
    final seenSectionKeys = <String>{};
    final seenSubsectionKeys = <String>{};

    for (final type in content.facilityTypes) {
      _checkNodeKey(issues, seenTypeKeys, type.key, 'facility type');
      _checkTitle(issues, type.key, type.title.base, 'Facility type');
      _checkLocalized(issues, type.key, type.title, type.description);
      _checkCapabilities(issues, type.key, type.capabilities, type.constraints);

      if (type.sections.isEmpty) {
        issues.add(CatalogIssue(
          level: CatalogIssueLevel.warning,
          nodeKey: type.key,
          field: 'sections',
          message: 'This facility type has no sections, so it will not '
              'appear to customers.',
        ));
      }

      if (type.enabled &&
          type.sections.isNotEmpty &&
          type.visibleSections.isEmpty) {
        issues.add(CatalogIssue(
          level: CatalogIssueLevel.warning,
          nodeKey: type.key,
          field: 'sections',
          message: 'Every section here is switched off, so this facility '
              'type will look empty.',
        ));
      }

      for (final section in type.sections) {
        _checkNodeKey(issues, seenSectionKeys, section.key, 'section');
        _checkTitle(issues, section.key, section.title.base, 'Section');
        _checkLocalized(
            issues, section.key, section.title, section.description);

        if (section.searchAliases.isEmpty) {
          issues.add(CatalogIssue(
            level: CatalogIssueLevel.warning,
            nodeKey: section.key,
            field: 'search_aliases',
            message: 'No category slug is linked, so this section will not '
                'match any live venues.',
          ));
        }

        for (final sub in section.subsections) {
          _checkNodeKey(issues, seenSubsectionKeys, sub.key, 'subsection');
          _checkTitle(issues, sub.key, sub.title.base, 'Subsection');
          _checkLocalized(issues, sub.key, sub.title, sub.description);
          _checkCapabilities(
              issues, sub.key, sub.capabilities, sub.constraints);
        }
        _checkCapabilities(
            issues, section.key, section.capabilities, section.constraints);
      }
    }

    return issues;
  }

  /// True when nothing blocks publishing.
  static bool canPublish(CatalogContent content) =>
      !validate(content).any((issue) => issue.isError);

  static void _checkNodeKey(
    List<CatalogIssue> issues,
    Set<String> seen,
    String key,
    String label,
  ) {
    if (!keyPattern.hasMatch(key)) {
      issues.add(CatalogIssue(
        level: CatalogIssueLevel.error,
        nodeKey: key,
        field: 'key',
        message: 'The id for this $label is not valid. Use lowercase '
            'letters, numbers and underscores.',
      ));
      return;
    }
    if (!seen.add(key)) {
      issues.add(CatalogIssue(
        level: CatalogIssueLevel.error,
        nodeKey: key,
        field: 'key',
        message: 'The id "$key" is used more than once. Ids must be unique.',
      ));
    }
  }

  static void _checkTitle(
    List<CatalogIssue> issues,
    String key,
    String title,
    String label,
  ) {
    final message = fieldTitle(title);
    if (message == null) return;
    issues.add(CatalogIssue(
      level: CatalogIssueLevel.error,
      nodeKey: key,
      field: 'title',
      message: '$label "$key": $message',
    ));
  }

  static void _checkLocalized(
    List<CatalogIssue> issues,
    String key,
    CmsLocalizedText title,
    CmsLocalizedText description,
  ) {
    final languages = <String>{
      ...title.overrides.keys,
      ...description.overrides.keys
    };
    for (final language in languages) {
      if (!_languageCode.hasMatch(language)) {
        issues.add(CatalogIssue(
          level: CatalogIssueLevel.error,
          nodeKey: key,
          field: 'translations',
          message: 'The language code "$language" is not valid.',
        ));
        continue;
      }
      final titleError = fieldTranslation(title.overrides[language]);
      if (titleError != null) {
        issues.add(CatalogIssue(
          level: CatalogIssueLevel.error,
          nodeKey: key,
          field: 'title.$language',
          message: 'Translation: $titleError',
        ));
      }
      final descriptionError =
          fieldDescription(description.overrides[language]);
      if (descriptionError != null) {
        issues.add(CatalogIssue(
          level: CatalogIssueLevel.error,
          nodeKey: key,
          field: 'description.$language',
          message: 'Translation: $descriptionError',
        ));
      }
    }
  }

  /// Validates capability configuration for a node.
  static void _checkCapabilities(
    List<CatalogIssue> issues,
    String nodeKey,
    FacilityCapabilities? capabilities,
    CapabilityConstraints? constraints,
  ) {
    if (capabilities == null || capabilities.isEmpty) return;

    final errors = capabilities.validate(constraints: constraints);
    for (final error in errors) {
      issues.add(CatalogIssue(
        level: CatalogIssueLevel.error,
        nodeKey: nodeKey,
        field: 'capabilities',
        message: error,
      ));
    }

    if (capabilities.timeSlots != null) {
      for (int i = 0; i < capabilities.timeSlots!.length; i++) {
        final slot = capabilities.timeSlots![i];
        if (slot.start.isEmpty || slot.end.isEmpty) {
          issues.add(CatalogIssue(
            level: CatalogIssueLevel.error,
            nodeKey: nodeKey,
            field: 'time_slots',
            message: 'Time slot ${i + 1} requires start and end times.',
          ));
        }
      }
    }
  }
}
