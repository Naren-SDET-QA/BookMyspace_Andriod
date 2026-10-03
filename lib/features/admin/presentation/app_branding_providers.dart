import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import 'admin_settings_providers.dart';

/// Parses `#RRGGBB`, `RRGGBB`, `#AARRGGBB` or `AARRGGBB` into a [Color].
///
/// Returns `null` for anything else so callers can fall back to the brand
/// colour instead of rendering an unexpected one.
Color? parseBrandHexColor(String? raw) {
  if (raw == null) return null;
  var cleaned = raw.trim();
  if (cleaned.startsWith('#')) cleaned = cleaned.substring(1);
  if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(cleaned)) {
    return Color(int.parse(cleaned, radix: 16));
  }
  return null;
}

/// Global branding edited by admins (logo, splash, app name, wordmark,
/// loading animation).
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
    this.animationEnabled = defaultAnimationEnabled,
    this.animationColor,
    this.animationThickness = defaultAnimationThickness,
  });

  /// Loading spinner defaults (match the original splash spinner).
  static const bool defaultAnimationEnabled = true;
  static const double defaultAnimationThickness = 2.5;
  static const double minAnimationThickness = 0.5;
  static const double maxAnimationThickness = 8.0;

  final String appName;
  final String tagline;
  final String? logoUrl;
  final String? logoDarkUrl;
  final String? splashUrl;
  final String? wordmarkFirstColor;
  final String? wordmarkRestColor;

  /// Whether the splash/loading spinner is shown.
  final bool animationEnabled;

  /// Spinner colour as a hex string; `null` means "use the brand colour".
  /// Only valid hex values survive [AppBranding.fromMap].
  final String? animationColor;

  /// Spinner stroke width in logical pixels, always within
  /// [minAnimationThickness]..[maxAnimationThickness].
  final double animationThickness;

  /// Clamps [value] into the supported spinner thickness range. Non-finite
  /// values fall back to [defaultAnimationThickness].
  static double clampThickness(num? value) {
    if (value == null) return defaultAnimationThickness;
    final v = value.toDouble();
    if (!v.isFinite) return defaultAnimationThickness;
    return v.clamp(minAnimationThickness, maxAnimationThickness).toDouble();
  }

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

    bool boolOpt(String key, bool fallback) {
      final v = map[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        switch (v.trim().toLowerCase()) {
          case 'true':
          case '1':
          case 'yes':
          case 'on':
            return true;
          case 'false':
          case '0':
          case 'no':
          case 'off':
            return false;
        }
      }
      return fallback;
    }

    double thicknessOpt(String key) {
      final v = map[key];
      if (v is num) return clampThickness(v);
      if (v is String) return clampThickness(double.tryParse(v.trim()));
      return defaultAnimationThickness;
    }

    final rawAnimationColor = opt('animation_color');

    return AppBranding(
      appName: str('app_name', 'BookMySpace'),
      tagline: str('tagline', ''),
      logoUrl: opt('logo_url'),
      logoDarkUrl: opt('logo_dark_url'),
      splashUrl: opt('splash_url'),
      wordmarkFirstColor: opt('wordmark_first_color') ?? '#3F51B5',
      wordmarkRestColor: opt('wordmark_rest_color'),
      animationEnabled: boolOpt('animation_enabled', defaultAnimationEnabled),
      animationColor: parseBrandHexColor(rawAnimationColor) == null
          ? null
          : rawAnimationColor,
      animationThickness: thicknessOpt('animation_thickness'),
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
    'animation_enabled': animationEnabled,
    'animation_color': animationColor,
    'animation_thickness': animationThickness,
  };

  static const defaults = AppBranding();

  /// Parsed spinner colour, or `null` to use the brand colour.
  Color? get animationColorValue => parseBrandHexColor(animationColor);

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
  try {
    final client = ref.watch(supabaseProvider);
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
