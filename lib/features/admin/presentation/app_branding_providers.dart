import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import 'admin_settings_providers.dart';

/// Global branding edited by admins (logo, splash, app name, wordmark).
///
/// Stored in the existing global `module_feature_configs` row with
/// module_key = 'branding'. Null / empty values fall back to bundled assets.
class AppBranding {
  const AppBranding({
    this.appName = 'BookMySpace',
    this.tagline = '',
    this.logoUrl,
    this.logoDarkUrl,
    this.splashUrl,
    this.wordmarkFirstColor = '#3F51B5',
    this.wordmarkRestColor,
  });

  final String appName;
  final String tagline;
  final String? logoUrl;
  final String? logoDarkUrl;
  final String? splashUrl;
  final String? wordmarkFirstColor;
  final String? wordmarkRestColor;

  factory AppBranding.fromMap(Map<String, dynamic> map) {
    String str(String key, String fallback) {
      final v = map[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return fallback;
    }

    String? opt(String key) {
      final v = map[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return null;
    }

    return AppBranding(
      appName: str('app_name', 'BookMySpace'),
      tagline: str('tagline', ''),
      logoUrl: opt('logo_url'),
      logoDarkUrl: opt('logo_dark_url'),
      splashUrl: opt('splash_url'),
      wordmarkFirstColor: opt('wordmark_first_color') ?? '#3F51B5',
      wordmarkRestColor: opt('wordmark_rest_color'),
    );
  }

  Map<String, dynamic> toMap() => {
    'app_name': appName,
    'tagline': tagline,
    'logo_url': logoUrl,
    'logo_dark_url': logoDarkUrl,
    'splash_url': splashUrl,
    'wordmark_first_color': wordmarkFirstColor,
    'wordmark_rest_color': wordmarkRestColor,
  };

  static const defaults = AppBranding();

  String? logoForBrightness(bool dark) {
    if (dark) return logoDarkUrl ?? logoUrl;
    return logoUrl;
  }
}

final appBrandingProvider = FutureProvider<AppBranding>((ref) async {
  try {
    final settings = await ref.watch(adminSettingsProvider.future);
    if (settings.branding.isNotEmpty) {
      return AppBranding.fromMap(settings.branding);
    }
  } catch (_) {
    // fall through to direct row read below
  }
    // Public customers without admin-read access still get branding via
    // the anon-readable global row.
    final client = ref.watch(supabaseProvider);
    try {
      final row = await client
          .from('module_feature_configs')
          .select('metadata')
          .eq('module_key', 'branding')
          .isFilter('venue_id', null)
          .maybeSingle();
      final meta = row?['metadata'];
      if (meta is Map) {
        return AppBranding.fromMap(Map<String, dynamic>.from(meta));
      }
    } catch (_) {}
    return AppBranding.defaults;
});
