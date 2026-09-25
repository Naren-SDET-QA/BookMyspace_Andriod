/// Reusable, data-driven form schema used by Education registration and
/// later by other owner types (sports, halls, healthcare).
///
/// Stored as JSON on the target row (`institutes.registration_form`) and
/// optionally overridden at the platform layer via `feature_flags.config`.
/// Never stores HTML, JavaScript, or executable code.
library;

enum ConfigurableFieldType {
  text,
  multiline,
  number,
  mobile,
  email,
  date,
  dropdown,
  radio,
  checkbox,
  multiSelect,
  fileUpload,
  imageUpload,
  documentUpload,
  url,
  location,
  address;

  static ConfigurableFieldType fromName(String? value) {
    return ConfigurableFieldType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ConfigurableFieldType.text,
    );
  }
}

class ConfigurableFieldDefinition {
  const ConfigurableFieldDefinition({
    required this.key,
    required this.label,
    required this.type,
    this.enabled = true,
    this.required = false,
    this.visible = true,
    this.placeholder = '',
    this.helpText = '',
    this.displayOrder = 0,
    this.options = const [],
    this.sensitive = false,
    this.custom = false,
    this.minLength,
    this.maxLength,
  });

  final String key;
  final String label;
  final ConfigurableFieldType type;
  final bool enabled;
  final bool required;
  final bool visible;
  final String placeholder;
  final String helpText;
  final int displayOrder;
  final List<String> options;
  final bool sensitive;
  final bool custom;
  final int? minLength;
  final int? maxLength;

  bool get isActive => enabled && visible;

  factory ConfigurableFieldDefinition.fromJson(Map<String, dynamic> json) {
    return ConfigurableFieldDefinition(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: ConfigurableFieldType.fromName(json['type'] as String?),
      enabled: json['enabled'] as bool? ?? true,
      required: json['required'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      placeholder: json['placeholder'] as String? ?? '',
      helpText: json['help_text'] as String? ?? '',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      options: (json['options'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      sensitive: json['sensitive'] as bool? ?? false,
      custom: json['custom'] as bool? ?? false,
      minLength: (json['min_length'] as num?)?.toInt(),
      maxLength: (json['max_length'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        'enabled': enabled,
        'required': required,
        'visible': visible,
        'placeholder': placeholder,
        'help_text': helpText,
        'display_order': displayOrder,
        'options': options,
        'sensitive': sensitive,
        'custom': custom,
        if (minLength != null) 'min_length': minLength,
        if (maxLength != null) 'max_length': maxLength,
      };

  ConfigurableFieldDefinition copyWith({
    String? label,
    ConfigurableFieldType? type,
    bool? enabled,
    bool? required,
    bool? visible,
    String? placeholder,
    String? helpText,
    int? displayOrder,
    List<String>? options,
    bool? sensitive,
    int? minLength,
    int? maxLength,
  }) {
    return ConfigurableFieldDefinition(
      key: key,
      label: label ?? this.label,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      required: required ?? this.required,
      visible: visible ?? this.visible,
      placeholder: placeholder ?? this.placeholder,
      helpText: helpText ?? this.helpText,
      displayOrder: displayOrder ?? this.displayOrder,
      options: options ?? this.options,
      sensitive: sensitive ?? this.sensitive,
      custom: custom,
      minLength: minLength ?? this.minLength,
      maxLength: maxLength ?? this.maxLength,
    );
  }
}

class ConfigurableFormSchema {
  const ConfigurableFormSchema({
    this.status = 'published',
    this.draftFields = const [],
    this.publishedFields = const [],
  });

  final String status;
  final List<ConfigurableFieldDefinition> draftFields;
  final List<ConfigurableFieldDefinition> publishedFields;

  bool get isPublished => status == 'published';

  List<ConfigurableFieldDefinition> get editorFields {
    final source = draftFields.isNotEmpty ? draftFields : publishedFields;
    final copy = [...source]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return copy;
  }

  /// Fields the student actually sees. Disabled/hidden fields are omitted.
  List<ConfigurableFieldDefinition> get activeFields {
    final source = isPublished && publishedFields.isNotEmpty
        ? publishedFields
        : editorFields;
    return source
        .where((field) => field.isActive && field.key.isNotEmpty)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  factory ConfigurableFormSchema.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return ConfigurableFormSchema.defaults();
    }
    List<ConfigurableFieldDefinition> read(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (item) => ConfigurableFieldDefinition.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((field) => field.key.isNotEmpty)
          .toList(growable: false);
    }

    return ConfigurableFormSchema(
      status: json['status'] as String? ?? 'published',
      draftFields: read(json['draft_fields'] ?? json['fields']),
      publishedFields: read(json['published_fields'] ?? json['fields']),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'draft_fields': draftFields.map((f) => f.toJson()).toList(),
        'published_fields': publishedFields.map((f) => f.toJson()).toList(),
      };

  ConfigurableFormSchema copyWith({
    String? status,
    List<ConfigurableFieldDefinition>? draftFields,
    List<ConfigurableFieldDefinition>? publishedFields,
  }) {
    return ConfigurableFormSchema(
      status: status ?? this.status,
      draftFields: draftFields ?? this.draftFields,
      publishedFields: publishedFields ?? this.publishedFields,
    );
  }

  ConfigurableFormSchema publish() {
    final ordered = [
      for (var i = 0; i < editorFields.length; i++)
        editorFields[i].copyWith(displayOrder: i),
    ];
    return copyWith(
      status: 'published',
      publishedFields: ordered,
      draftFields: ordered,
    );
  }

  /// Owner/admin setup errors. Empty means the schema may be published.
  List<String> setupErrors() {
    final errors = <String>[];
    for (final field in editorFields) {
      if (!field.enabled) continue;
      if (field.required && !field.visible) {
        errors.add('${field.label} is required so it cannot be hidden.');
      }
      if (field.required &&
          (field.type == ConfigurableFieldType.dropdown ||
              field.type == ConfigurableFieldType.radio ||
              field.type == ConfigurableFieldType.multiSelect) &&
          field.options.isEmpty) {
        errors.add('${field.label} needs at least one option.');
      }
      if (field.key.isEmpty) {
        errors.add('Every field needs an internal key.');
      }
    }
    if (!editorFields.any((f) => f.isActive)) {
      errors.add('Enable at least one registration field.');
    }
    return errors;
  }

  /// Student-side answer validation. Returns field key → message.
  Map<String, String> validateAnswers(Map<String, dynamic> answers) {
    final errors = <String, String>{};
    for (final field in activeFields) {
      final raw = answers[field.key];
      final text = raw == null ? '' : raw.toString().trim();
      final empty = text.isEmpty ||
          (raw is List && raw.isEmpty) ||
          (raw is bool && raw == false);
      if (field.required && empty) {
        errors[field.key] = '${field.label} is required.';
        continue;
      }
      if (empty) continue;
      switch (field.type) {
        case ConfigurableFieldType.email:
          if (!text.contains('@') || !text.contains('.')) {
            errors[field.key] = 'Enter a valid email.';
          }
        case ConfigurableFieldType.mobile:
          final digits = text.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 10) {
            errors[field.key] = 'Enter a 10-digit mobile number.';
          }
        case ConfigurableFieldType.url:
          final uri = Uri.tryParse(text);
          if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
            errors[field.key] = 'Enter a valid http(s) URL.';
          }
        case ConfigurableFieldType.number:
          if (num.tryParse(text) == null) {
            errors[field.key] = 'Enter a number.';
          }
        default:
          break;
      }
      if (field.minLength != null && text.length < field.minLength!) {
        errors[field.key] = '${field.label} is too short.';
      }
      if (field.maxLength != null && text.length > field.maxLength!) {
        errors[field.key] = '${field.label} is too long.';
      }
    }
    return errors;
  }

  ConfigurableFormSchema withoutAadhaar() {
    bool keep(ConfigurableFieldDefinition field) =>
        field.key != 'aadhaar' && field.key != 'aadhaar_upload';
    return copyWith(
      draftFields: draftFields.where(keep).toList(),
      publishedFields: publishedFields.where(keep).toList(),
    );
  }

  /// Shipped catalog of possible education registration fields. Owners enable
  /// a subset; they never need a Flutter change to add one of these.
  static List<ConfigurableFieldDefinition> catalog({
    List<ConfigurableFieldDefinition>? platformOverlay,
  }) {
    if (platformOverlay != null && platformOverlay.isNotEmpty) {
      return platformOverlay;
    }
    return const [
      ConfigurableFieldDefinition(
        key: 'full_name',
        label: 'Full Name',
        type: ConfigurableFieldType.text,
        required: true,
        placeholder: 'Student full name',
        displayOrder: 0,
      ),
      ConfigurableFieldDefinition(
        key: 'mobile',
        label: 'Mobile Number',
        type: ConfigurableFieldType.mobile,
        required: true,
        placeholder: '10-digit mobile',
        displayOrder: 1,
      ),
      ConfigurableFieldDefinition(
        key: 'email',
        label: 'Email',
        type: ConfigurableFieldType.email,
        required: false,
        displayOrder: 2,
      ),
      ConfigurableFieldDefinition(
        key: 'gender',
        label: 'Gender',
        type: ConfigurableFieldType.dropdown,
        enabled: false,
        options: ['Female', 'Male', 'Other', 'Prefer not to say'],
        displayOrder: 3,
      ),
      ConfigurableFieldDefinition(
        key: 'date_of_birth',
        label: 'Date of Birth',
        type: ConfigurableFieldType.date,
        enabled: false,
        sensitive: true,
        displayOrder: 4,
      ),
      ConfigurableFieldDefinition(
        key: 'age',
        label: 'Age',
        type: ConfigurableFieldType.number,
        enabled: false,
        displayOrder: 5,
      ),
      ConfigurableFieldDefinition(
        key: 'aadhaar',
        label: 'Aadhaar Number',
        type: ConfigurableFieldType.text,
        enabled: false,
        required: false,
        visible: false,
        sensitive: true,
        helpText: 'Collected only when this institute enables Aadhaar.',
        minLength: 12,
        maxLength: 12,
        displayOrder: 6,
      ),
      ConfigurableFieldDefinition(
        key: 'aadhaar_upload',
        label: 'Aadhaar upload',
        type: ConfigurableFieldType.documentUpload,
        enabled: false,
        visible: false,
        sensitive: true,
        displayOrder: 7,
      ),
      ConfigurableFieldDefinition(
        key: 'id_proof',
        label: 'Passport / ID proof',
        type: ConfigurableFieldType.documentUpload,
        enabled: false,
        sensitive: true,
        displayOrder: 8,
      ),
      ConfigurableFieldDefinition(
        key: 'student_photo',
        label: 'Student photo',
        type: ConfigurableFieldType.imageUpload,
        enabled: false,
        displayOrder: 9,
      ),
      ConfigurableFieldDefinition(
        key: 'father_name',
        label: 'Father Name',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 10,
      ),
      ConfigurableFieldDefinition(
        key: 'mother_name',
        label: 'Mother Name',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 11,
      ),
      ConfigurableFieldDefinition(
        key: 'guardian_name',
        label: 'Guardian Name',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 12,
      ),
      ConfigurableFieldDefinition(
        key: 'guardian_mobile',
        label: 'Guardian Mobile',
        type: ConfigurableFieldType.mobile,
        enabled: false,
        displayOrder: 13,
      ),
      ConfigurableFieldDefinition(
        key: 'permanent_address',
        label: 'Permanent Address',
        type: ConfigurableFieldType.address,
        enabled: false,
        sensitive: true,
        displayOrder: 14,
      ),
      ConfigurableFieldDefinition(
        key: 'current_address',
        label: 'Current Address',
        type: ConfigurableFieldType.address,
        enabled: false,
        sensitive: true,
        displayOrder: 15,
      ),
      ConfigurableFieldDefinition(
        key: 'city',
        label: 'City',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 16,
      ),
      ConfigurableFieldDefinition(
        key: 'district',
        label: 'District',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 17,
      ),
      ConfigurableFieldDefinition(
        key: 'state',
        label: 'State',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 18,
      ),
      ConfigurableFieldDefinition(
        key: 'pin_code',
        label: 'PIN Code',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 19,
      ),
      ConfigurableFieldDefinition(
        key: 'qualification',
        label: 'Education Qualification',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 20,
      ),
      ConfigurableFieldDefinition(
        key: 'college_school',
        label: 'College / School',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 21,
      ),
      ConfigurableFieldDefinition(
        key: 'year_of_passing',
        label: 'Year of Passing',
        type: ConfigurableFieldType.number,
        enabled: false,
        displayOrder: 22,
      ),
      ConfigurableFieldDefinition(
        key: 'marks',
        label: 'Marks / Percentage',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 23,
      ),
      ConfigurableFieldDefinition(
        key: 'occupation',
        label: 'Occupation',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 24,
      ),
      ConfigurableFieldDefinition(
        key: 'work_experience',
        label: 'Work Experience',
        type: ConfigurableFieldType.multiline,
        enabled: false,
        displayOrder: 25,
      ),
      ConfigurableFieldDefinition(
        key: 'preferred_batch',
        label: 'Preferred Batch',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 26,
      ),
      ConfigurableFieldDefinition(
        key: 'preferred_course',
        label: 'Preferred Course',
        type: ConfigurableFieldType.text,
        enabled: false,
        displayOrder: 27,
      ),
      ConfigurableFieldDefinition(
        key: 'preferred_language',
        label: 'Preferred Language',
        type: ConfigurableFieldType.dropdown,
        enabled: false,
        options: ['English', 'Hindi', 'Telugu', 'Tamil', 'Kannada'],
        displayOrder: 28,
      ),
      ConfigurableFieldDefinition(
        key: 'notes',
        label: 'Notes',
        type: ConfigurableFieldType.multiline,
        enabled: false,
        displayOrder: 29,
      ),
    ];
  }

  /// New institutes start with Name + Mobile + Email. Aadhaar is off.
  static ConfigurableFormSchema defaults() {
    final fields = catalog()
        .map(
          (field) => switch (field.key) {
            'full_name' || 'mobile' => field.copyWith(
                enabled: true,
                required: true,
                visible: true,
              ),
            'email' => field.copyWith(enabled: true, visible: true),
            _ => field.copyWith(enabled: false, required: false),
          },
        )
        .toList();
    return ConfigurableFormSchema(
      status: 'published',
      draftFields: fields,
      publishedFields: fields,
    );
  }
}

class SensitiveFieldPolicy {
  static const keys = {
    'aadhaar',
    'aadhaar_upload',
    'id_proof',
    'date_of_birth',
    'permanent_address',
    'current_address',
  };

  static bool isSensitive(String key) => keys.contains(key);

  static String maskAadhaar(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return 'XXXX';
    final last4 = digits.substring(digits.length - 4);
    return 'XXXX-XXXX-$last4';
  }

  /// Public payload (masked) vs owner-only sensitive payload.
  static ({Map<String, dynamic> public, Map<String, dynamic> sensitive}) split(
    Map<String, dynamic> answers,
  ) {
    final public = <String, dynamic>{};
    final sensitive = <String, dynamic>{};
    answers.forEach((key, value) {
      if (isSensitive(key)) {
        if (key == 'aadhaar' && value != null) {
          public[key] = maskAadhaar(value.toString());
        }
        sensitive[key] = value;
      } else {
        public[key] = value;
      }
    });
    return (public: public, sensitive: sensitive);
  }
}
