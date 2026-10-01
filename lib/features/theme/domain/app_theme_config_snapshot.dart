import '../../../core/theme/app_theme_config.dart';

/// Draft and published snapshots returned by the admin theme RPCs.
class AppThemeConfigSnapshot {
  const AppThemeConfigSnapshot({
    required this.draft,
    required this.published,
    required this.draftVersion,
    required this.publishedVersion,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.publishedAt,
    this.publishedBy,
    this.isEmpty = false,
  });

  final AppThemeConfig draft;
  final AppThemeConfig published;
  final int draftVersion;
  final int publishedVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final DateTime? publishedAt;
  final String? publishedBy;
  final bool isEmpty;

  factory AppThemeConfigSnapshot.fromJson(Map<String, dynamic> json) {
    return AppThemeConfigSnapshot(
      draft: AppThemeConfig.fromJson(json['draft_config']),
      published: AppThemeConfig.fromJson(json['published_config']),
      draftVersion: _int(json['draft_version'], 1),
      publishedVersion: _int(json['published_version'], 1),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      updatedBy: json['updated_by'] as String?,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      publishedBy: json['published_by'] as String?,
      isEmpty: json['draft_config'] == null && json['published_config'] == null,
    );
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}
