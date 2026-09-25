import 'package:flutter/material.dart';

class AdminSettings {
  const AdminSettings({
    this.home = const {},
    this.theme = const {},
    this.modules = const {},
    this.push = const {},
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

  static const pushSection = 'push_notifications';
  static const pushEnabledKey = 'enabled';

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
      // home_layout: 'glass' (existing, default) | 'modern' (category tiles).
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
  }) => AdminSettings(
    home: home ?? this.home,
    theme: theme ?? this.theme,
    modules: modules ?? this.modules,
    push: push ?? this.push,
  );

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
