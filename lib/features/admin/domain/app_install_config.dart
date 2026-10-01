import 'package:flutter/foundation.dart';

/// Admin-controlled install offer stored in `module_feature_configs`
/// (`module_key` `app_install`, `venue_id` null).
///
/// Web offers the browser install prompt. Android offers a Play Store https
/// link and a direct APK https link. Anything other than https is rejected
/// so a saved value cannot navigate to `javascript:` or another scheme.
class AppInstallConfig {
  const AppInstallConfig({
    this.webEnabled = false,
    this.androidEnabled = false,
    this.apkEnabled = false,
    this.playStoreUrl = '',
    this.apkUrl = '',
    this.title = '',
    this.message = '',
  });

  static const defaultTitle = 'Install BookMySpace';
  static const defaultMessage = 'Add BookMySpace to your phone.';

  static const Map<String, dynamic> defaultMap = {
    'web_enabled': false,
    'android_enabled': false,
    'apk_enabled': false,
    'play_store_url': '',
    'apk_url': '',
    'title': defaultTitle,
    'message': defaultMessage,
  };

  final bool webEnabled;
  final bool androidEnabled;
  final bool apkEnabled;
  final String playStoreUrl;
  final String apkUrl;
  final String title;
  final String message;

  static AppInstallConfig fromMap(Map<String, dynamic>? raw) {
    final map = raw ?? const <String, dynamic>{};
    return AppInstallConfig(
      webEnabled: map['web_enabled'] == true,
      androidEnabled: map['android_enabled'] == true,
      apkEnabled: map['apk_enabled'] == true,
      playStoreUrl: _text(map['play_store_url']),
      apkUrl: _text(map['apk_url']),
      title: _text(map['title'], max: 80),
      message: _text(map['message'], max: 180),
    );
  }

  Map<String, dynamic> toMap() => {
    'web_enabled': webEnabled,
    'android_enabled': androidEnabled,
    'apk_enabled': apkEnabled,
    'play_store_url': playStoreUrl.trim(),
    'apk_url': apkUrl.trim(),
    'title': title.trim(),
    'message': message.trim(),
  };

  String get displayTitle => title.trim().isEmpty ? defaultTitle : title.trim();

  String get displayMessage =>
      message.trim().isEmpty ? defaultMessage : message.trim();

  /// Why this config cannot be saved, or null when it is safe to store.
  String? get saveError {
    if (androidEnabled && !isPlayStoreHttpsUrl(playStoreUrl)) {
      return 'Play Store link must be an https://play.google.com/store URL.';
    }
    if (apkEnabled && !isHttpsUrl(apkUrl)) {
      return 'APK link must be an https URL.';
    }
    return null;
  }

  bool get hasPlayLink => androidEnabled && isPlayStoreHttpsUrl(playStoreUrl);

  bool get hasApkLink => apkEnabled && isHttpsUrl(apkUrl);

  /// Options a customer should see on [surface].
  ///
  /// iPhone users only get the web Add to Home Screen instructions. The Play
  /// Store and APK are Android installs, shown in the browser (except iOS)
  /// and in the Android app.
  List<AppInstallChoice> choicesFor(
    AppInstallSurface surface, {
    bool webInstalled = false,
  }) {
    final choices = <AppInstallChoice>[];
    final onWeb =
        surface == AppInstallSurface.web || surface == AppInstallSurface.webIos;
    if (webEnabled && onWeb && !webInstalled) {
      choices.add(AppInstallChoice.web);
    }
    final canInstallAndroid =
        surface == AppInstallSurface.web ||
        surface == AppInstallSurface.android;
    if (hasPlayLink && canInstallAndroid) choices.add(AppInstallChoice.play);
    if (hasApkLink && canInstallAndroid) choices.add(AppInstallChoice.apk);
    return choices;
  }
}

enum AppInstallChoice { web, play, apk }

/// Where the customer is running the app. [webIos] is Safari on iPhone,
/// which has no Play Store or APK install.
enum AppInstallSurface { web, webIos, android, ios, other }

AppInstallSurface currentAppInstallSurface() {
  if (kIsWeb) {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? AppInstallSurface.webIos
        : AppInstallSurface.web;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AppInstallSurface.android,
    TargetPlatform.iOS => AppInstallSurface.ios,
    _ => AppInstallSurface.other,
  };
}

/// True only for an https Play Store listing. Other hosts are rejected.
bool isPlayStoreHttpsUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https') return false;
  if (uri.userInfo.isNotEmpty || uri.host.toLowerCase() != 'play.google.com') {
    return false;
  }
  return uri.path.toLowerCase().contains('/store');
}

/// True for an absolute https URL with a host. Used for the APK download.
bool isHttpsUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'https') return false;
  return uri.userInfo.isEmpty && uri.host.isNotEmpty;
}

String _text(Object? value, {int max = 2048}) {
  if (value is! String) return '';
  final trimmed = value.trim();
  if (trimmed.length <= max) return trimmed;
  return trimmed.substring(0, max);
}
