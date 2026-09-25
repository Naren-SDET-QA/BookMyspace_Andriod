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
    supabaseUrl: 'https://configure-supabase-url.invalid',
    supabaseAnonKey: 'SUPABASE_ANON_KEY_REQUIRED',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://configure-supabase-url.invalid/functions/v1',
  ),
  testing(
    name: 'testing',
    supabaseUrl: 'https://configure-supabase-url.invalid',
    supabaseAnonKey: 'SUPABASE_ANON_KEY_REQUIRED',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://configure-supabase-url.invalid/functions/v1',
  ),
  staging(
    name: 'staging',
    supabaseUrl: 'https://configure-supabase-url.invalid',
    supabaseAnonKey: 'SUPABASE_ANON_KEY_REQUIRED',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://configure-supabase-url.invalid/functions/v1',
  ),
  production(
    name: 'production',
    supabaseUrl: 'https://configure-supabase-url.invalid',
    supabaseAnonKey: 'SUPABASE_ANON_KEY_REQUIRED',
    razorpayKeyId: 'rzp_live_PLACEHOLDER',
    apiBaseUrl: 'https://configure-supabase-url.invalid/functions/v1',
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

  static const String _supabaseUrlDefine = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const String _supabaseAnonKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String _apiBaseUrlDefine = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _razorpayKeyIdDefine = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
  );
  static const String _razorpayTestKeyIdDefine = String.fromEnvironment(
    'RAZORPAY_TEST_KEY_ID',
  );
  static const String _devTestEmailDefine = String.fromEnvironment(
    'DEV_TEST_EMAIL',
  );
  static const String _devTestPasswordDefine = String.fromEnvironment(
    'DEV_TEST_PASSWORD',
  );
  static const String _webAuthRedirectDefine = String.fromEnvironment(
    'WEB_AUTH_REDIRECT_URI',
  );

  /// OneSignal App ID (public client identifier, not a secret). Sourced
  /// from --dart-define=ONESIGNAL_APP_ID=... at build time; never hardcode
  /// a real value here. Empty means push registration is disabled (mirrors
  /// how Firebase push silently no-op'd without native config).
  static const String _oneSignalAppIdDefine = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
  );
  static const String _supabasePublishableKeyDefine =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String _developmentOtpEnabledDefine =
      String.fromEnvironment('BMS_DEV_OTP_ENABLED');
  static const String _uiTestModeDefine =
      String.fromEnvironment('BMS_UI_TEST_MODE');

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
  static String get razorpayKeyId {
    final testKey = _razorpayTestKeyIdDefine.isNotEmpty
        ? _razorpayTestKeyIdDefine
        : _razorpayKeyIdDefine;
    if (environment == AppEnvironment.production) {
      // Never let a DEV TEST key override production configuration.
      if (testKey.startsWith('rzp_test_')) return environment.razorpayKeyId;
      return _razorpayKeyIdDefine.isNotEmpty
          ? _razorpayKeyIdDefine
          : environment.razorpayKeyId;
    }
    return testKey.isNotEmpty ? testKey : environment.razorpayKeyId;
  }

  static String get apiBaseUrl {
    if (_apiBaseUrlDefine.isNotEmpty) return _apiBaseUrlDefine;
    if (environment == AppEnvironment.local) return environment.apiBaseUrl;
    if (isPlaceholderSupabaseHost ||
        !(supabaseUrl.startsWith('https://') ||
            supabaseUrl.startsWith('http://'))) {
      return environment.apiBaseUrl;
    }
    return '${supabaseUrl.replaceFirst(RegExp(r'/$'), '')}/functions/v1';
  }
  static String get devTestEmail => _devTestEmailDefine;
  static String get devTestPassword => _devTestPasswordDefine;
  static String get oneSignalAppId => _oneSignalAppIdDefine;

  /// The callback must stay on the origin that created the PKCE verifier.
  /// A dart-define can pin this for a stable local port; otherwise the
  /// browser's current origin is used.
  static String get webAuthRedirectUri {
    if (_webAuthRedirectDefine.isNotEmpty) return _webAuthRedirectDefine;
    if (kIsWeb) {
      final uri = Uri.base;
      return uri.replace(path: '/', query: '', fragment: '').toString();
    }
    return '';
  }

  /// Native (iOS/Android) OAuth deep-link redirect. A fixed app-scheme URL
  /// (not environment-dependent like [webAuthRedirectUri]) that iOS/Android
  /// are registered to hand back to this app after Google/Apple sign-in.
  /// Must also be added to the Supabase project's Redirect URLs allow-list.
  static const String nativeAuthRedirectUri =
      'com.bookmyspace.bookmyspace://login-callback/';

  /// Redirect target for the password-recovery email.
  /// Web lands on `/reset-password`; native reuses the existing OAuth scheme.
  static String get passwordResetRedirectUri {
    if (kIsWeb) {
      final base = Uri.tryParse(webAuthRedirectUri);
      if (base != null && base.hasScheme) {
        return base.replace(path: '/reset-password', query: '', fragment: '').toString();
      }
    }
    return nativeAuthRedirectUri;
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

  /// Allows navigation-only test access in non-production environments.
  /// This never creates or claims an authenticated Supabase session.
  static bool get allowUnauthenticatedTestAccess =>
      environment == AppEnvironment.development ||
      environment == AppEnvironment.testing;
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
