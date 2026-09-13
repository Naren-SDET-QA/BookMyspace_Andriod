/// Server-backed configuration for an already implemented optional module.
///
/// This model is never used for authentication or route authorization. A
/// module manifest defines the safe client contract; the server controls its
/// enabled state and validated JSON configuration.
class FeatureFlag {
  const FeatureFlag({
    required this.key,
    required this.enabled,
    required this.platforms,
    required this.config,
    this.updatedAt,
    this.updatedBy,
  });

  final String key;
  final bool enabled;
  final List<String> platforms;
  final Map<String, dynamic> config;
  final DateTime? updatedAt;
  final String? updatedBy;

  bool enabledFor(String platform) => enabled && platforms.contains(platform);

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    final rawPlatforms = json['platforms'];
    final rawConfig = json['config'];
    return FeatureFlag(
      key: json['key'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      platforms: rawPlatforms is List
          ? rawPlatforms.whereType<String>().toList(growable: false)
          : const ['ios', 'android', 'web'],
      config: rawConfig is Map
          ? rawConfig.map((key, value) => MapEntry(key.toString(), value))
          : const <String, dynamic>{},
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      updatedBy: json['updated_by'] as String?,
    );
  }
}
