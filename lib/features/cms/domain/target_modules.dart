/// Per-target module toggles. Platform `feature_flags` remain the master
/// on/off for whole products (`courses`, `demo_registration`,
/// `course_feedback`). This overlay lets an Owner hide a module on *their*
/// institute without a Flutter change and without a second CMS.
///
/// The same shape can later attach to a venue, gym, or hall via
/// [targetType] + JSON stored on that row.
library;

class TargetModuleConfig {
  const TargetModuleConfig(this.flags);

  final Map<String, bool> flags;

  static const catalog = <String, String>{
    'registration': 'Registration',
    'faculty': 'Faculty',
    'demo': 'Demo',
    'gallery': 'Gallery',
    'brochure': 'Brochure',
    'location': 'Address',
    'map': 'Location map',
    'aadhaar': 'Aadhaar collection',
    'documents': 'Document collection',
    'online': 'Online classes',
    'offline': 'Offline classes',
    'reviews': 'Reviews',
    'occupancy': 'Popular times',
    'seats': 'Seat availability',
    'discounts': 'Discounts',
    'coupons': 'Coupons',
    'installments': 'Installments',
    'certificates': 'Certificates',
    'faq': 'FAQ',
  };

  /// Safe defaults: Aadhaar/occupancy/installments off until explicitly enabled.
  static const defaults = <String, bool>{
    'registration': true,
    'faculty': true,
    'demo': true,
    'gallery': true,
    'brochure': true,
    'location': true,
    'map': true,
    'aadhaar': false,
    'documents': false,
    'online': true,
    'offline': true,
    'reviews': true,
    'occupancy': false,
    'seats': true,
    'discounts': true,
    'coupons': true,
    'installments': false,
    'certificates': true,
    'faq': true,
  };

  bool enabled(String key) => flags[key] ?? defaults[key] ?? false;

  /// Hide the section entirely when the module is off, the platform flag is
  /// off, or there is no real data. Never leave an empty placeholder.
  bool show({
    required String key,
    required bool hasData,
    bool platformEnabled = true,
  }) {
    if (!platformEnabled) return false;
    if (!enabled(key)) return false;
    return hasData;
  }

  factory TargetModuleConfig.fromJson(Object? json) {
    if (json is! Map) return const TargetModuleConfig({});
    final flags = <String, bool>{};
    json.forEach((key, value) {
      if (value is bool) flags[key.toString()] = value;
    });
    return TargetModuleConfig(flags);
  }

  Map<String, bool> toJson() => {
        for (final key in catalog.keys) key: enabled(key),
      };

  TargetModuleConfig copyWithFlag(String key, bool value) {
    return TargetModuleConfig({...toJson(), key: value});
  }

  /// Platform `feature_flags.config.modules` overlay. Missing keys keep
  /// [defaults]. A platform `false` cannot be turned on by an owner.
  TargetModuleConfig mergePlatform(Map<String, dynamic> platform) {
    final merged = Map<String, bool>.from(toJson());
    platform.forEach((key, value) {
      if (value is bool && value == false) merged[key] = false;
    });
    return TargetModuleConfig(merged);
  }
}

/// Maps education modules onto existing platform feature-flag keys so we
/// never create a parallel module table.
String? platformFlagForModule(String moduleKey) {
  return switch (moduleKey) {
    'registration' || 'demo' || 'brochure' => 'demo_registration',
    'reviews' => 'course_feedback',
    'coupons' => 'offers',
    _ => 'courses',
  };
}
