/// Admin-configurable listing template shared by every category.
///
/// Stored in `venue_categories.metadata.listing`. Missing or unpublished
/// config falls back to a slug-based default so a new category still uses
/// the same customer UI without a Flutter rebuild.
library;

enum ListingFieldType {
  text,
  number,
  dropdown,
  date,
  time,
  slot,
  toggle;

  static ListingFieldType fromName(String? value) {
    return ListingFieldType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ListingFieldType.text,
    );
  }
}

enum ListingFilterType {
  options,
  range,
  toggle;

  static ListingFilterType fromName(String? value) {
    return ListingFilterType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ListingFilterType.options,
    );
  }
}

class ListingFieldDefinition {
  const ListingFieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.placeholder = '',
    this.displayOrder = 0,
    this.isActive = true,
  });

  final String key;
  final String label;
  final ListingFieldType type;
  final bool required;
  final List<String> options;
  final String placeholder;
  final int displayOrder;
  final bool isActive;

  factory ListingFieldDefinition.fromJson(Map<String, dynamic> json) {
    return ListingFieldDefinition(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: ListingFieldType.fromName(json['type'] as String?),
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      placeholder: json['placeholder'] as String? ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        'required': required,
        'options': options,
        'placeholder': placeholder,
        'display_order': displayOrder,
        'is_active': isActive,
      };

  ListingFieldDefinition copyWith({
    String? label,
    ListingFieldType? type,
    bool? required,
    List<String>? options,
    String? placeholder,
    int? displayOrder,
    bool? isActive,
  }) {
    return ListingFieldDefinition(
      key: key,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? this.options,
      placeholder: placeholder ?? this.placeholder,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ListingFilterGroup {
  const ListingFilterGroup({
    required this.id,
    required this.label,
    this.type = ListingFilterType.options,
    this.options = const [],
  });

  final String id;
  final String label;
  final ListingFilterType type;
  final List<String> options;

  factory ListingFilterGroup.fromJson(Map<String, dynamic> json) {
    return ListingFilterGroup(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: ListingFilterType.fromName(json['type'] as String?),
      options: (json['options'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'options': options,
      };
}

class ListingTemplateConfig {
  const ListingTemplateConfig({
    required this.templateId,
    this.published = true,
    this.ctaBook = 'Book & Pay',
    this.ctaAvailability = 'Availability',
    this.ctaCall = 'Call',
    this.ctaChat = 'Chat',
    this.accentColor,
    this.fields = const [],
    this.specKeys = const ['capacity', 'parking', 'food', 'hours'],
    this.filterGroups = const [],
    this.showCall = true,
    this.showChat = true,
  });

  final String templateId;
  final bool published;
  final String ctaBook;
  final String ctaAvailability;
  final String ctaCall;
  final String ctaChat;
  final String? accentColor;
  final List<ListingFieldDefinition> fields;
  final List<String> specKeys;
  final List<ListingFilterGroup> filterGroups;
  final bool showCall;
  final bool showChat;

  bool get isPublished => published;

  List<ListingFieldDefinition> get activeFields {
    final active = fields.where((field) => field.isActive).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return active;
  }

  List<ListingFieldDefinition> get bookingFields => activeFields
      .where((field) => field.type != ListingFieldType.slot)
      .toList(growable: false);

  factory ListingTemplateConfig.fromJson(Map<String, dynamic> json) {
    return ListingTemplateConfig(
      templateId: json['template'] as String? ?? 'generic',
      published: json['published'] as bool? ?? true,
      ctaBook: json['cta_book'] as String? ?? 'Book & Pay',
      ctaAvailability: json['cta_availability'] as String? ?? 'Availability',
      ctaCall: json['cta_call'] as String? ?? 'Call',
      ctaChat: json['cta_chat'] as String? ?? 'Chat',
      accentColor: json['accent_color'] as String?,
      fields: (json['fields'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (row) => ListingFieldDefinition.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
      specKeys: (json['spec_keys'] as List? ?? const ['capacity', 'parking'])
          .whereType<String>()
          .toList(growable: false),
      filterGroups: (json['filter_groups'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (row) =>
                ListingFilterGroup.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
      showCall: json['show_call'] as bool? ?? true,
      showChat: json['show_chat'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'template': templateId,
        'published': published,
        'cta_book': ctaBook,
        'cta_availability': ctaAvailability,
        'cta_call': ctaCall,
        'cta_chat': ctaChat,
        if (accentColor != null) 'accent_color': accentColor,
        'fields': fields.map((field) => field.toJson()).toList(),
        'spec_keys': specKeys,
        'filter_groups': filterGroups.map((group) => group.toJson()).toList(),
        'show_call': showCall,
        'show_chat': showChat,
      };

  ListingTemplateConfig copyWith({
    String? templateId,
    bool? published,
    String? ctaBook,
    String? ctaAvailability,
    String? ctaCall,
    String? ctaChat,
    String? accentColor,
    bool clearAccent = false,
    List<ListingFieldDefinition>? fields,
    List<String>? specKeys,
    List<ListingFilterGroup>? filterGroups,
    bool? showCall,
    bool? showChat,
  }) {
    return ListingTemplateConfig(
      templateId: templateId ?? this.templateId,
      published: published ?? this.published,
      ctaBook: ctaBook ?? this.ctaBook,
      ctaAvailability: ctaAvailability ?? this.ctaAvailability,
      ctaCall: ctaCall ?? this.ctaCall,
      ctaChat: ctaChat ?? this.ctaChat,
      accentColor: clearAccent ? null : accentColor ?? this.accentColor,
      fields: fields ?? this.fields,
      specKeys: specKeys ?? this.specKeys,
      filterGroups: filterGroups ?? this.filterGroups,
      showCall: showCall ?? this.showCall,
      showChat: showChat ?? this.showChat,
    );
  }

  static ListingTemplateConfig? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return ListingTemplateConfig.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Merges an admin-stored overlay onto the slug default.
  static ListingTemplateConfig resolve({
    String? slug,
    String? parentSection,
    ListingTemplateConfig? stored,
  }) {
    final fallback = defaultsFor(slug: slug, parentSection: parentSection);
    if (stored == null) return fallback;
    return stored.copyWith(
      fields: stored.fields.isEmpty ? fallback.fields : stored.fields,
      specKeys: stored.specKeys.isEmpty ? fallback.specKeys : stored.specKeys,
      filterGroups: stored.filterGroups.isEmpty
          ? fallback.filterGroups
          : stored.filterGroups,
    );
  }

  /// Stable template keys. Admin can append new keys for future
  /// categories without changing Flutter code; new slugs map to a default
  /// template via [defaultsFor].
  static List<String> templateIds = [
    'generic',
    'hall',
    'hotel',
    'education',
    'temple',
    'sports',
    'studio',
    'pg',
  ];

  static ListingTemplateConfig defaultsFor({
    String? slug,
    String? parentSection,
  }) {
    final haystack = '${slug ?? ''} ${parentSection ?? ''}'.toLowerCase();
    if (_matches(haystack, const [
      'hotel',
      'lodge',
      'stay',
      'guest_house',
      'resort',
      'hourly',
    ])) {
      return _hotel;
    }
    if (_matches(haystack, const [
      'institute',
      'class',
      'course',
      'coaching',
      'tuition',
      'education',
      'school',
    ])) {
      return _education;
    }
    if (_matches(haystack, const ['temple', 'darshan', 'pooja'])) {
      return _temple;
    }
    if (_matches(haystack, const ['sport', 'turf', 'gym', 'fitness'])) {
      return _sports;
    }
    if (_matches(haystack, const ['studio', 'photo', 'film'])) {
      return _studio;
    }
    if (_matches(haystack, const ['pg', 'hostel', 'coliving', 'co_living'])) {
      return _pg;
    }
    if (_matches(haystack, const [
      'hall',
      'banquet',
      'function',
      'marriage',
      'convention',
      'party',
      'auditorium',
      'meeting',
    ])) {
      return _hall;
    }
    return _generic;
  }

  static bool _matches(String haystack, List<String> tokens) {
    return tokens.any(haystack.contains);
  }
}

const _date = ListingFieldDefinition(
  key: 'date',
  label: 'Date',
  type: ListingFieldType.date,
  required: true,
  displayOrder: 0,
);
const _slot = ListingFieldDefinition(
  key: 'time_slot',
  label: 'Time slot',
  type: ListingFieldType.slot,
  required: true,
  displayOrder: 10,
);

final _generic = ListingTemplateConfig(
  templateId: 'generic',
  fields: const [_date, _slot],
  filterGroups: const [
    ListingFilterGroup(
        id: 'price', label: 'Price', type: ListingFilterType.range),
  ],
);

final _hall = ListingTemplateConfig(
  templateId: 'hall',
  fields: const [
    _date,
    _slot,
    ListingFieldDefinition(
      key: 'guests',
      label: 'Guests',
      type: ListingFieldType.number,
      required: true,
      placeholder: 'Expected guests',
      displayOrder: 20,
    ),
    ListingFieldDefinition(
      key: 'facilities',
      label: 'Facilities',
      type: ListingFieldType.dropdown,
      options: ['AC', 'Catering', 'Stage', 'Decoration'],
      displayOrder: 30,
    ),
  ],
  specKeys: const ['capacity', 'parking', 'food', 'hours'],
  filterGroups: const [
    ListingFilterGroup(
        id: 'price', label: 'Price', type: ListingFilterType.range),
    ListingFilterGroup(
      id: 'amenities',
      label: 'Facilities',
      options: ['Parking', 'AC', 'Catering', 'Stage'],
    ),
  ],
);

final _hotel = ListingTemplateConfig(
  templateId: 'hotel',
  ctaBook: 'Book Stay',
  fields: const [
    ListingFieldDefinition(
      key: 'check_in',
      label: 'Check-in',
      type: ListingFieldType.date,
      required: true,
    ),
    ListingFieldDefinition(
      key: 'check_out',
      label: 'Check-out',
      type: ListingFieldType.date,
      required: true,
      displayOrder: 5,
    ),
    ListingFieldDefinition(
      key: 'guests',
      label: 'Guests',
      type: ListingFieldType.number,
      required: true,
      displayOrder: 20,
    ),
    ListingFieldDefinition(
      key: 'rooms',
      label: 'Rooms',
      type: ListingFieldType.number,
      required: true,
      displayOrder: 30,
    ),
    _slot,
  ],
  specKeys: const ['capacity', 'hours', 'parking'],
);

final _education = ListingTemplateConfig(
  templateId: 'education',
  ctaBook: 'Enrol / Book Demo',
  ctaAvailability: 'Batches',
  fields: const [
    ListingFieldDefinition(
      key: 'mode',
      label: 'Mode',
      type: ListingFieldType.dropdown,
      options: ['Online', 'Offline', 'Hybrid'],
      required: true,
    ),
    ListingFieldDefinition(
      key: 'duration',
      label: 'Duration',
      type: ListingFieldType.text,
      placeholder: 'Weeks or hours',
      displayOrder: 10,
    ),
    ListingFieldDefinition(
      key: 'faculty',
      label: 'Faculty',
      type: ListingFieldType.text,
      displayOrder: 20,
    ),
    ListingFieldDefinition(
      key: 'fee',
      label: 'Fee',
      type: ListingFieldType.number,
      displayOrder: 30,
    ),
    ListingFieldDefinition(
      key: 'demo',
      label: 'Demo',
      type: ListingFieldType.toggle,
      displayOrder: 40,
    ),
    _date,
    _slot,
  ],
  specKeys: const ['capacity', 'hours'],
);

final _temple = ListingTemplateConfig(
  templateId: 'temple',
  ctaBook: 'Book Darshan',
  fields: const [
    ListingFieldDefinition(
      key: 'darshan_date',
      label: 'Darshan date',
      type: ListingFieldType.date,
      required: true,
    ),
    _slot,
    ListingFieldDefinition(
      key: 'pooja_type',
      label: 'Pooja type',
      type: ListingFieldType.dropdown,
      options: ['General Darshan', 'Special Pooja', 'Abhishekam'],
      required: true,
      displayOrder: 20,
    ),
    ListingFieldDefinition(
      key: 'devotees',
      label: 'Devotees',
      type: ListingFieldType.number,
      required: true,
      displayOrder: 30,
    ),
  ],
  specKeys: const ['capacity', 'hours'],
);

final _sports = ListingTemplateConfig(
  templateId: 'sports',
  ctaBook: 'Book Slot',
  fields: const [
    _date,
    ListingFieldDefinition(
      key: 'duration',
      label: 'Duration (hours)',
      type: ListingFieldType.number,
      required: true,
      displayOrder: 5,
    ),
    _slot,
    ListingFieldDefinition(
      key: 'players',
      label: 'Players',
      type: ListingFieldType.number,
      required: true,
      displayOrder: 20,
    ),
    ListingFieldDefinition(
      key: 'equipment',
      label: 'Equipment',
      type: ListingFieldType.dropdown,
      options: ['Included', 'Bring your own'],
      displayOrder: 30,
    ),
  ],
  specKeys: const ['capacity', 'parking', 'hours'],
);

final _studio = ListingTemplateConfig(
  templateId: 'studio',
  fields: const [
    _date,
    _slot,
    ListingFieldDefinition(
      key: 'session_type',
      label: 'Session type',
      type: ListingFieldType.dropdown,
      options: ['Photo', 'Video', 'Podcast', 'Rehearsal'],
      required: true,
      displayOrder: 20,
    ),
    ListingFieldDefinition(
      key: 'equipment',
      label: 'Equipment',
      type: ListingFieldType.text,
      displayOrder: 30,
    ),
  ],
  specKeys: const ['capacity', 'hours', 'parking'],
);

final _pg = ListingTemplateConfig(
  templateId: 'pg',
  ctaBook: 'Book Deposit',
  ctaAvailability: 'Rooms',
  fields: const [
    ListingFieldDefinition(
      key: 'check_in',
      label: 'Move-in date',
      type: ListingFieldType.date,
      required: true,
    ),
    ListingFieldDefinition(
      key: 'guests',
      label: 'Occupants',
      type: ListingFieldType.number,
      required: true,
      displayOrder: 20,
    ),
    ListingFieldDefinition(
      key: 'rooms',
      label: 'Sharing',
      type: ListingFieldType.dropdown,
      options: ['Single', 'Double', 'Triple'],
      displayOrder: 30,
    ),
  ],
  specKeys: const ['capacity', 'food', 'parking'],
);
