import 'package:flutter/foundation.dart';
import 'env_model.dart';

/// Supported runtime environments.
///
/// Secrets must never be committed. Real values come from
/// `--dart-define` flags at build time (see the `--dart-define` examples in
/// the README). The defaults below are safe placeholders only.
enum AppEnvironment {
  local(
    name: 'local',
    supabaseUrl: 'http://127.0.0.1:54321',
    supabaseAnonKey: 'LOCAL_ANON_KEY',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'http://127.0.0.1:8080',
  ),
  development(
    name: 'development',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'DEV_ANON_KEY',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  testing(
    name: 'testing',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'TEST_ANON_KEY',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  staging(
    name: 'staging',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'STAGING_ANON_KEY',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  production(
    name: 'production',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'PROD_ANON_KEY',
    razorpayKeyId: 'rzp_live_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  );

  const AppEnvironment({
    required this.name,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.razorpayKeyId,
    required this.apiBaseUrl,
  });

  final String name;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String razorpayKeyId;
  final String apiBaseUrl;

  static const String _envDefine = String.fromEnvironment('APP_ENV');

  /// Converts environment to [EnvModel].
  EnvModel toModel() => EnvModel(
        name: name,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        razorpayKeyId: razorpayKeyId,
        apiBaseUrl: apiBaseUrl,
      );

  /// Resolves the active environment from `--dart-define=APP_ENV=...`.
  static AppEnvironment get current {
    if (_envDefine.isNotEmpty) {
      return AppEnvironment.values.firstWhere(
        (e) => e.name == _envDefine,
        orElse: () => AppEnvironment.development,
      );
    }
    if (kReleaseMode) return AppEnvironment.production;
    if (kProfileMode) return AppEnvironment.staging;
    return AppEnvironment.development;
  }
}

/// App-wide configuration resolved once at startup.
class AppConfig {
  const AppConfig._();

  static const String _supabaseUrlDefine =
      String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKeyDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _supabasePublishableKeyDefine =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String _developmentOtpEnabledDefine =
      String.fromEnvironment('BMS_DEV_OTP_ENABLED');
  static const String _uiTestModeDefine =
      String.fromEnvironment('BMS_UI_TEST_MODE');
  static const String _razorpayKeyIdDefine =
      String.fromEnvironment('RAZORPAY_KEY_ID');

  static AppEnvironment get environment => AppEnvironment.current;

  /// Returns active [EnvModel] populated from environment and dart-defines.
  static EnvModel get activeEnv => EnvModel(
        name: environment.name,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        razorpayKeyId: razorpayKeyId,
        apiBaseUrl: apiBaseUrl,
      );

  static String get supabaseUrl => _supabaseUrlDefine.isNotEmpty
      ? _supabaseUrlDefine
      : environment.supabaseUrl;
  static String get supabaseAnonKey => _supabasePublishableKeyDefine.isNotEmpty
      ? _supabasePublishableKeyDefine
      : (_supabaseAnonKeyDefine.isNotEmpty
          ? _supabaseAnonKeyDefine
          : environment.supabaseAnonKey);
  static String get razorpayKeyId => _razorpayKeyIdDefine.isNotEmpty
      ? _razorpayKeyIdDefine
      : environment.razorpayKeyId;
  static String get apiBaseUrl {
    if (!isPlaceholderSupabaseHost &&
        (supabaseUrl.startsWith('https://') ||
            supabaseUrl.startsWith('http://'))) {
      return '${supabaseUrl.replaceAll(RegExp(r'/$'), '')}/functions/v1';
    }
    return environment.apiBaseUrl;
  }
  static String get appName => 'BookMySpace';

  /// Host-only view of [supabaseUrl] for diagnostics. Never includes keys.
  static String get supabaseHost {
    final parsed = Uri.tryParse(supabaseUrl);
    if (parsed != null && parsed.host.isNotEmpty) return parsed.host;
    return '';
  }

  /// True when the compile-time URL is still the source placeholder.
  ///
  /// DNS lowercases this to `your_project.supabase.co`, which is the failed
  /// host lookup seen when `--dart-define-from-file` is missing.
  static bool get isPlaceholderSupabaseHost =>
      isPlaceholderSupabaseHostFor(supabaseUrl);

  static bool isPlaceholderSupabaseHostFor(String url) {
    final host = (Uri.tryParse(url)?.host ?? url).toLowerCase();
    return host.contains('your_project');
  }

  /// Whether the app has real Supabase runtime configuration rather than the
  /// safe placeholders used by source-control examples and local tests.
  static bool get isSupabaseConfigured {
    const placeholderKeys = {
      'LOCAL_ANON_KEY',
      'DEV_ANON_KEY',
      'TEST_ANON_KEY',
      'STAGING_ANON_KEY',
      'PROD_ANON_KEY',
      'sb_publishable_dev_key',
    };
    return (supabaseUrl.startsWith('https://') ||
            supabaseUrl.startsWith('http://')) &&
        !isPlaceholderSupabaseHost &&
        !placeholderKeys.contains(supabaseAnonKey);
  }

  /// Environment helpers
  static bool get isDevelopment =>
      environment == AppEnvironment.development ||
      environment == AppEnvironment.local;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isRazorpayTestMode => razorpayKeyId.startsWith('rzp_test_');

  /// Enables the temporary phone OTP only for local debug development builds.
  ///
  /// A configured Supabase development build uses real phone OTP by default.
  /// The temporary provider remains available for local builds without real
  /// Supabase configuration, or when explicitly enabled for an isolated test.
  /// The compile-time flag can disable it, but it can never enable it in
  /// profile or release builds because [debugMode] is checked first.
  static bool get isTemporaryDevelopmentPhoneOtpEnabled =>
      isTemporaryDevelopmentPhoneOtpEnabledFor(
        debugMode: kDebugMode,
        development: isDevelopment,
        flag: _developmentOtpEnabledDefine,
        supabaseConfigured: isSupabaseConfigured,
      );

  static bool isTemporaryDevelopmentPhoneOtpEnabledFor({
    required bool debugMode,
    required bool development,
    required String flag,
    bool supabaseConfigured = false,
  }) {
    if (!debugMode || !development || supabaseConfigured) return false;

    final normalizedFlag = flag.trim().toLowerCase();
    if (normalizedFlag == 'false') return false;
    if (normalizedFlag == 'true') return true;

    return !supabaseConfigured;
  }

  /// Opens protected screens for visual/interaction testing without creating
  /// an authenticated session or changing any repository behavior.
  ///
  /// This is deliberately limited to debug development builds. It cannot be
  /// enabled in profile or release builds, even if the dart-define is passed.
  static bool get isUiTestMode => isUiTestModeFor(
        debugMode: kDebugMode,
        development: isDevelopment,
        flag: _uiTestModeDefine,
      );

  static bool isUiTestModeFor({
    required bool debugMode,
    required bool development,
    required String flag,
  }) =>
      debugMode && development && flag.trim().toLowerCase() == 'true';

  /// Safe diagnostic summary of active environment settings (no sensitive keys exposed).
  static Map<String, dynamic> get environmentSummary => {
        ...activeEnv.toSummaryMap(),
        'placeholderHost': isPlaceholderSupabaseHost,
        'supabaseConfigured': isSupabaseConfigured,
      };

  /// Booking hold duration before automatic expiry (server enforced too).
  static const Duration bookingHoldDuration = Duration(minutes: 10);
  static const int requestTimeoutSeconds = 20;
  static const int maxRetries = 3;
}
