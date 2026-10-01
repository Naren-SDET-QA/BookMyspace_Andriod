import 'package:flutter/material.dart';

import 'app_install_config.dart';

class AdminSettings {
  const AdminSettings({
    this.home = const {},
    this.theme = const {},
    this.modules = const {},
    this.push = const {},
    this.install = const {},
    this.branding = const {},
  });
  final Map<String, dynamic> home;
  final Map<String, dynamic> theme;
  final Map<String, dynamic> modules;

  /// Push Notifications / OneSignal settings, stored as the global
  /// `module_feature_configs` row with module_key [pushSection].
  /// Only the on/off switch lives here; the OneSignal App ID comes from the
  /// build environment (ONESIGNAL_APP_ID) and the REST API key only ever
  /// lives in Supabase Edge Function secrets.
  final Map<String, dynamic> push;

  /// Web, Play Store, and APK install offer. Stored as module_key
  /// [installSection]. Customers only see a channel an admin turned on.
  final Map<String, dynamic> install;

  /// Global branding (logo, splash, app name, wordmark colors).
  /// Stored as module_key [brandingSection]. Empty = bundled assets.
  final Map<String, dynamic> branding;

  static const pushSection = 'push_notifications';
  static const pushEnabledKey = 'enabled';
  static const installSection = 'app_install';
  static const brandingSection = 'branding';

  /// OFF by default: OneSignal is never initialised unless an admin
  /// explicitly turns push on.
  bool get pushNotificationsEnabled => flag(push[pushEnabledKey]);

  static const defaults = AdminSettings(
    home: {
      'search_placeholder': 'Search hotels, PGs, venues...',
      'hero_title': 'Find your perfect space',
      'hero_subtitle': 'Discover and book spaces that fit your needs.',
      'primary_booking_button_text': 'Book Now',
      'home_banner_visible': true,
      'search_banner_visible': true,
      // Optional extra Home page: admin chooses which Home is shown.
      // home_layout: 'glass' (existing, default) | 'modern' (category tiles)
      // | 'premium' (hero search, offers, recently viewed)
      // | 'moment' (light "Your Space for Every Moment")
      // | 'life' (dark "Spaces for Your Life").
      // bottom_nav_style: 'classic' (existing 6 tabs, default) | 'modern'.
      'home_layout': 'glass',
      'bottom_nav_style': 'classic',
      'tile_spaces_visible': true,
      'tile_institutes_visible': true,
      'tile_classes_visible': true,
      'tile_pg_visible': true,
      'tile_stays_visible': true,
      'tile_shopping_visible': true,
      'space_radar_visible': true,
      'activity_visible': true,
    },
    install: AppInstallConfig.defaultMap,
    theme: {
      'primary_color': '#3F51B5',
      'accent_color': '#757DE8',
      'banner_background': '#EEF1FF',
      'banner_text_color': '#17204A',
    },
  );

  AdminSettings copyWith({
    Map<String, dynamic>? home,
    Map<String, dynamic>? theme,
    Map<String, dynamic>? modules,
    Map<String, dynamic>? push,
    Map<String, dynamic>? install,
    Map<String, dynamic>? branding,
  }) => AdminSettings(
    home: home ?? this.home,
    theme: theme ?? this.theme,
    modules: modules ?? this.modules,
    push: push ?? this.push,
    install: install ?? this.install,
    branding: branding ?? this.branding,
  );

  AppInstallConfig get appInstall => AppInstallConfig.fromMap(install);

  /// Branding helpers with safe fallbacks.
  String get appName => text(branding['app_name'], 'BookMySpace');
  String? get logoUrl {
    final v = branding['logo_url'];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  String? get logoDarkUrl {
    final v = branding['logo_dark_url'];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  String? get splashUrl {
    final v = branding['splash_url'];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  static bool validHex(String value) =>
      RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value.trim());
  static String text(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  static bool flag(Object? value, {bool fallback = false}) =>
      value is bool ? value : fallback;
  static Color color(Object? value, Color fallback) {
    final raw = value?.toString() ?? '';
    if (!validHex(raw)) return fallback;
    return Color(
      int.parse(raw.substring(1), radix: 16) |
          (raw.length == 7 ? 0xFF000000 : 0),
    );
  }
}
