/// Runtime configuration for the E2E suites.
///
/// Everything is supplied through `--dart-define`, so no credential is ever
/// committed, and nothing here is ever printed or logged.
enum E2eMode { mock, live }

/// Tag names used by every suite (Flutter and Playwright alike).
abstract final class E2eTags {
  static const smoke = 'smoke';
  static const critical = 'critical';
  static const auth = 'auth';
  static const booking = 'booking';
  static const owner = 'owner';
  static const negative = 'negative';
  static const payment = 'payment';
  static const admin = 'admin';
}

abstract final class E2eEnv {
  static const String _mode = String.fromEnvironment(
    'E2E_MODE',
    defaultValue: 'mock',
  );

  /// Comma-separated tag filter, e.g. `smoke` or `booking,negative`.
  /// Empty means "register every flow".
  static const String _tags = String.fromEnvironment('E2E_TAGS');

  // Live DEV credentials: dart-defines only, never defaults.
  static const String userEmail = String.fromEnvironment('E2E_USER_EMAIL');
  static const String userPassword = String.fromEnvironment(
    'E2E_USER_PASSWORD',
  );
  static const String ownerEmail = String.fromEnvironment('E2E_OWNER_EMAIL');
  static const String ownerPassword = String.fromEnvironment(
    'E2E_OWNER_PASSWORD',
  );

  /// Where live OTP codes come from: `mailpit` (local Supabase mail
  /// catcher) or `none` (OTP flows are reported as not runnable).
  static const String otpSource = String.fromEnvironment(
    'E2E_OTP_SOURCE',
    defaultValue: 'none',
  );
  static const String mailpitUrl = String.fromEnvironment('E2E_MAILPIT_URL');

  static const String appEnv = String.fromEnvironment('APP_ENV');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static E2eMode get mode => _mode == 'live' ? E2eMode.live : E2eMode.mock;

  static Set<String> get requestedTags => {
    for (final tag in _tags.split(','))
      if (tag.trim().isNotEmpty) tag.trim(),
  };

  /// Returns why a live run must not start, or null when it may.
  ///
  /// Live E2E is DEV-only: it refuses any environment other than `dev`.
  static String? liveModeProblem() {
    if (appEnv != 'dev') {
      return 'Live E2E requires --dart-define=APP_ENV=dev (got "$appEnv").';
    }
    if (supabaseUrl.isEmpty) {
      return 'Live E2E requires --dart-define=SUPABASE_URL for the DEV project.';
    }
    if (userEmail.isEmpty || userPassword.isEmpty) {
      return 'Live E2E requires E2E_USER_EMAIL and E2E_USER_PASSWORD.';
    }
    return null;
  }
}
