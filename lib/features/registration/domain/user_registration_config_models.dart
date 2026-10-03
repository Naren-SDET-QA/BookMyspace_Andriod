
/// Target module to which a user registration field applies.
enum RegistrationTargetModule {
  all(
    code: 'all',
    displayName: 'All User Types',
    description: 'Applicable to all registrations across all modules',
  ),
  customer(
    code: 'customer',
    displayName: 'Customer / Member',
    description: 'Regular booking customers & members',
  ),
  venueOwner(
    code: 'venue_owner',
    displayName: 'Venue & Space Owner',
    description: 'Property, court, and hall owners / hosts',
  ),
  instituteStudent(
    code: 'institute_student',
    displayName: 'Institute Student / Coach',
    description: 'Academy students, trainees & coaches',
  ),
  eventAttendee(
    code: 'event_attendee',
    displayName: 'Event / Tournament Attendee',
    description: 'Tournament & workshop participants',
  );

  const RegistrationTargetModule({
    required this.code,
    required this.displayName,
    required this.description,
  });

  final String code;
  final String displayName;
  final String description;

  static RegistrationTargetModule fromCode(String? code) {
    if (code == null) return RegistrationTargetModule.all;
    return RegistrationTargetModule.values.firstWhere(
      (m) => m.code.toLowerCase() == code.toLowerCase(),
      orElse: () => RegistrationTargetModule.all,
    );
  }
}

/// Category grouping for registration fields to create clean sectioned forms.
enum RegistrationFieldCategory {
  personal(
    displayName: 'Personal Information',
    iconName: 'Person',
  ),
  identityKyc(
    displayName: 'Government ID & KYC',
    iconName: 'Badge',
  ),
  address(
    displayName: 'Address & Location',
    iconName: 'LocationOn',
  ),
  professionalBusiness(
    displayName: 'Business & Academy Details',
    iconName: 'Business',
  ),
  custom(
    displayName: 'Custom & Additional Fields',
    iconName: 'Extension',
  );

  const RegistrationFieldCategory({
    required this.displayName,
    required this.iconName,
  });

  final String displayName;
  final String iconName;

  static RegistrationFieldCategory fromName(String? name) {
    if (name == null) return RegistrationFieldCategory.personal;
    return RegistrationFieldCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase() ||
             c.displayName.toLowerCase() == name.toLowerCase(),
      orElse: () => RegistrationFieldCategory.personal,
    );
  }
}

/// Data input types supported for configurable user registration fields.
enum RegistrationFieldType {
  photo(displayName: 'Profile Photo / Selfie', hasOptions: false),
  text(displayName: 'Single Line Text', hasOptions: false),
  phone(displayName: 'Mobile / WhatsApp Number', hasOptions: false),
  email(displayName: 'Email Address', hasOptions: false),
  aadhaar(displayName: 'Aadhaar Number (12 Digits)', hasOptions: false),
  govtId(displayName: 'Govt ID / PAN / Driving License', hasOptions: false),
  addressLine(displayName: 'Street / House / Building Address', hasOptions: false),
  locationHierarchy(displayName: 'Location Hierarchy (Country → State → City → Area)', hasOptions: false),
  pincode(displayName: 'Postal PIN Code (6 Digits)', hasOptions: false),
  dateOfBirth(displayName: 'Date of Birth', hasOptions: false),
  dropdown(displayName: 'Dropdown Selection', hasOptions: true),
  radioGroup(displayName: 'Radio Options', hasOptions: true),
  checkbox(displayName: 'Toggle / Agreement Checkbox', hasOptions: false),
  number(displayName: 'Numeric Input', hasOptions: false),
  textarea(displayName: 'Multi-line Text Area', hasOptions: false);

  const RegistrationFieldType({
    required this.displayName,
    required this.hasOptions,
  });

  final String displayName;
  final bool hasOptions;

  static RegistrationFieldType fromName(String? name) {
    if (name == null) return RegistrationFieldType.text;
    return RegistrationFieldType.values.firstWhere(
      (t) => t.name.toLowerCase() == name.toLowerCase() ||
             t.displayName.toLowerCase() == name.toLowerCase(),
      orElse: () => RegistrationFieldType.text,
    );
  }
}

/// Centralized dynamic user registration field definition.
class UserRegistrationFieldDefinition {
  const UserRegistrationFieldDefinition({
    required this.id,
    required this.key,
    required this.label,
    required this.fieldType,
    this.category = RegistrationFieldCategory.personal,
    this.targetModule = RegistrationTargetModule.all,
    this.required = false,
    this.isEnabled = true,
    this.placeholder = '',
    this.helpText = '',
    this.defaultValue = '',
    this.options = const [],
    this.displayOrder = 0,
    this.isSystemStandard = false,
    this.validationRegex = '',
    this.createdAt,
  });

  final String id;
  final String key;
  final String label;
  final RegistrationFieldType fieldType;
  final RegistrationFieldCategory category;
  final RegistrationTargetModule targetModule;
  final bool required;
  final bool isEnabled;
  final String placeholder;
  final String helpText;
  final String defaultValue;
  final List<String> options;
  final int displayOrder;
  final bool isSystemStandard;
  final String validationRegex;
  final int? createdAt;

  UserRegistrationFieldDefinition copyWith({
    String? id,
    String? key,
    String? label,
    RegistrationFieldType? fieldType,
    RegistrationFieldCategory? category,
    RegistrationTargetModule? targetModule,
    bool? required,
    bool? isEnabled,
    String? placeholder,
    String? helpText,
    String? defaultValue,
    List<String>? options,
    int? displayOrder,
    bool? isSystemStandard,
    String? validationRegex,
    int? createdAt,
  }) {
    return UserRegistrationFieldDefinition(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      fieldType: fieldType ?? this.fieldType,
      category: category ?? this.category,
      targetModule: targetModule ?? this.targetModule,
      required: required ?? this.required,
      isEnabled: isEnabled ?? this.isEnabled,
      placeholder: placeholder ?? this.placeholder,
      helpText: helpText ?? this.helpText,
      defaultValue: defaultValue ?? this.defaultValue,
      options: options ?? this.options,
      displayOrder: displayOrder ?? this.displayOrder,
      isSystemStandard: isSystemStandard ?? this.isSystemStandard,
      validationRegex: validationRegex ?? this.validationRegex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'label': label,
    'field_type': fieldType.name,
    'category': category.name,
    'target_module': targetModule.code,
    'required': required,
    'is_enabled': isEnabled,
    'placeholder': placeholder,
    'help_text': helpText,
    'default_value': defaultValue,
    'options': options,
    'display_order': displayOrder,
    'is_system_standard': isSystemStandard,
    'validation_regex': validationRegex,
    'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  factory UserRegistrationFieldDefinition.fromJson(Map<String, dynamic> json) {
    return UserRegistrationFieldDefinition(
      id: json['id'] as String? ?? 'field_${DateTime.now().millisecondsSinceEpoch}',
      key: json['key'] as String? ?? json['field_key'] as String? ?? '',
      label: json['label'] as String? ?? json['display_label'] as String? ?? '',
      fieldType: RegistrationFieldType.fromName(json['field_type'] as String? ?? json['fieldType'] as String?),
      category: RegistrationFieldCategory.fromName(json['category'] as String?),
      targetModule: RegistrationTargetModule.fromCode(json['target_module'] as String? ?? json['targetModule'] as String?),
      required: json['required'] as bool? ?? false,
      isEnabled: json['is_enabled'] as bool? ?? json['isEnabled'] as bool? ?? json['enabled'] as bool? ?? true,
      placeholder: json['placeholder'] as String? ?? '',
      helpText: json['help_text'] as String? ?? json['helpText'] as String? ?? '',
      defaultValue: json['default_value'] as String? ?? json['defaultValue'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      displayOrder: json['display_order'] as int? ?? json['displayOrder'] as int? ?? 0,
      isSystemStandard: json['is_system_standard'] as bool? ?? json['isSystemStandard'] as bool? ?? false,
      validationRegex: json['validation_regex'] as String? ?? json['validationRegex'] as String? ?? '',
      createdAt: json['created_at'] as int?,
    );
  }
}

/// Standard 17 default registration fields mirroring the official BookMySpace schema.
final List<UserRegistrationFieldDefinition> sampleDefaultRegistrationFields = [
  const UserRegistrationFieldDefinition(
    id: 'reg_photo',
    key: 'photo_url',
    label: 'Profile Photo / Selfie',
    fieldType: RegistrationFieldType.photo,
    category: RegistrationFieldCategory.personal,
    targetModule: RegistrationTargetModule.all,
    required: false,
    isEnabled: true,
    placeholder: 'Upload profile photo or select avatar',
    helpText: 'Used for account badge, booking verification and check-ins',
    displayOrder: 1,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_full_name',
    key: 'full_name',
    label: 'Full Name (as per Govt ID)',
    fieldType: RegistrationFieldType.text,
    category: RegistrationFieldCategory.personal,
    targetModule: RegistrationTargetModule.all,
    required: true,
    isEnabled: true,
    placeholder: 'e.g. Narendra Reddy',
    helpText: 'Legal name for bookings, passes, and invoices',
    displayOrder: 2,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_phone',
    key: 'phone',
    label: 'Mobile / WhatsApp Number',
    fieldType: RegistrationFieldType.phone,
    category: RegistrationFieldCategory.personal,
    targetModule: RegistrationTargetModule.all,
    required: true,
    isEnabled: true,
    placeholder: '+91 98765 43210',
    helpText: '10-digit mobile number for instant SMS/WhatsApp booking OTPs',
    displayOrder: 3,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_email',
    key: 'email',
    label: 'Email Address',
    fieldType: RegistrationFieldType.email,
    category: RegistrationFieldCategory.personal,
    targetModule: RegistrationTargetModule.all,
    required: true,
    isEnabled: true,
    placeholder: 'user@example.com',
    helpText: 'Official receipts and slot confirmation tickets are sent here',
    displayOrder: 4,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_gender',
    key: 'gender',
    label: 'Gender',
    fieldType: RegistrationFieldType.radioGroup,
    category: RegistrationFieldCategory.personal,
    targetModule: RegistrationTargetModule.all,
    required: false,
    isEnabled: true,
    options: ['Male', 'Female', 'Other', 'Prefer not to say'],
    defaultValue: 'Male',
    displayOrder: 5,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_dob',
    key: 'dob',
    label: 'Date of Birth',
    fieldType: RegistrationFieldType.dateOfBirth,
    category: RegistrationFieldCategory.personal,
    targetModule: RegistrationTargetModule.all,
    required: false,
    isEnabled: true,
    placeholder: 'DD/MM/YYYY (e.g. 15/08/1995)',
    helpText: 'Age eligibility for tournaments and academy batches',
    displayOrder: 6,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_aadhaar',
    key: 'aadhaar_number',
    label: 'Aadhaar Card Number (12 Digits)',
    fieldType: RegistrationFieldType.aadhaar,
    category: RegistrationFieldCategory.identityKyc,
    targetModule: RegistrationTargetModule.all,
    required: false,
    isEnabled: true,
    placeholder: '1234 5678 9012',
    helpText: 'Government KYC verification for security check-ins and host onboarding',
    displayOrder: 7,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_govt_id',
    key: 'govt_id_number',
    label: 'Alternate Govt ID (PAN / Passport / Voter ID)',
    fieldType: RegistrationFieldType.govtId,
    category: RegistrationFieldCategory.identityKyc,
    targetModule: RegistrationTargetModule.all,
    required: false,
    isEnabled: true,
    placeholder: 'e.g. ABCDE1234F',
    helpText: 'Optional alternate ID for verification',
    displayOrder: 8,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_address_line1',
    key: 'address_line_1',
    label: 'Address Line 1 (Flat/House No, Street, Building)',
    fieldType: RegistrationFieldType.addressLine,
    category: RegistrationFieldCategory.address,
    targetModule: RegistrationTargetModule.all,
    required: true,
    isEnabled: true,
    placeholder: 'e.g. Flat 402, Sai Residency, Road No. 36',
    displayOrder: 9,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_address_line2',
    key: 'address_line_2',
    label: 'Address Line 2 (Area, Landmark, Sector)',
    fieldType: RegistrationFieldType.addressLine,
    category: RegistrationFieldCategory.address,
    targetModule: RegistrationTargetModule.all,
    required: false,
    isEnabled: true,
    placeholder: 'e.g. Near Metro Pillar 1420, Jubilee Hills',
    displayOrder: 10,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_location_hierarchy',
    key: 'location_hierarchy',
    label: 'Country, State, District & City Hierarchy',
    fieldType: RegistrationFieldType.locationHierarchy,
    category: RegistrationFieldCategory.address,
    targetModule: RegistrationTargetModule.all,
    required: true,
    isEnabled: true,
    helpText: 'Select your home base region for localized slot discovery',
    displayOrder: 11,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_pincode',
    key: 'pincode',
    label: 'Postal PIN Code (6 Digits)',
    fieldType: RegistrationFieldType.pincode,
    category: RegistrationFieldCategory.address,
    targetModule: RegistrationTargetModule.all,
    required: true,
    isEnabled: true,
    placeholder: '500033',
    displayOrder: 12,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_emergency_contact',
    key: 'emergency_contact',
    label: 'Emergency Contact / Alternate Phone',
    fieldType: RegistrationFieldType.phone,
    category: RegistrationFieldCategory.personal,
    targetModule: RegistrationTargetModule.all,
    required: false,
    isEnabled: true,
    placeholder: '+91 91234 56789',
    displayOrder: 13,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_org_name',
    key: 'organization_name',
    label: 'Business / Academy / Club Entity Name',
    fieldType: RegistrationFieldType.text,
    category: RegistrationFieldCategory.professionalBusiness,
    targetModule: RegistrationTargetModule.venueOwner,
    required: true,
    isEnabled: true,
    placeholder: 'e.g. Smash Badminton Arena LLP',
    helpText: 'Official registered company or club name',
    displayOrder: 14,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_gstin',
    key: 'gstin',
    label: 'GSTIN / Commercial Tax Registration Number',
    fieldType: RegistrationFieldType.govtId,
    category: RegistrationFieldCategory.professionalBusiness,
    targetModule: RegistrationTargetModule.venueOwner,
    required: false,
    isEnabled: true,
    placeholder: '36AAAAA0000A1Z5',
    helpText: 'For B2B tax invoicing on commission and payout credits',
    displayOrder: 15,
    isSystemStandard: true,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_skill_level',
    key: 'skill_level',
    label: 'Sport / Activity Skill Level',
    fieldType: RegistrationFieldType.dropdown,
    category: RegistrationFieldCategory.custom,
    targetModule: RegistrationTargetModule.instituteStudent,
    required: false,
    isEnabled: true,
    options: ['Beginner', 'Intermediate', 'Advanced', 'State Player', 'Certified Coach'],
    defaultValue: 'Beginner',
    displayOrder: 16,
    isSystemStandard: false,
  ),
  const UserRegistrationFieldDefinition(
    id: 'reg_special_requests',
    key: 'special_requests',
    label: 'Special Requirements / Medical Notes',
    fieldType: RegistrationFieldType.textarea,
    category: RegistrationFieldCategory.custom,
    targetModule: RegistrationTargetModule.all,
    required: false,
    isEnabled: true,
    placeholder: 'Any sports injuries, racket stringing preferences, or accessibility needs...',
    displayOrder: 17,
    isSystemStandard: false,
  ),
];
