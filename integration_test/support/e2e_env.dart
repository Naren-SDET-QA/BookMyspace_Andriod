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

  /// Runs against the DEV Supabase project (`E2E_MODE=live` only).
  static const live = 'live';

  /// Customer cancellation journeys.
  static const cancellation = 'cancellation';

  /// Flows that take more than ten minutes (live hold expiry).
  static const slow = 'slow';
}

/// The only backend live E2E may ever reach.
///
/// Live mode is DEV-only by construction: the project ref is the one the
/// DEV seed (`supabase/seed_dev_e2e.sql`) guards on, and any other host
/// (PROD, staging, a typo) is refused before the app or Supabase starts.
abstract final class E2eLiveGuard {
  static const devProjectRef = 'zykxneztahxbjduagutv';
  static const devSupabaseHost = '$devProjectRef.supabase.co';

  /// Returns why a live run must not start, or null when it may.
  ///
  /// Pure (no dart-defines) so the refusal rules are unit tested. Messages
  /// name the missing setting, never a credential value.
  static String? problem({
    required String appEnv,
    required String supabaseUrl,
    required bool hasSupabaseAnonKey,
    required String userEmail,
    required String userPassword,
  }) {
    if (appEnv != 'dev') {
      return 'Live E2E requires --dart-define=APP_ENV=dev (got "$appEnv").';
    }
    if (supabaseUrl.isEmpty) {
      return 'Live E2E requires --dart-define=SUPABASE_URL for the DEV project.';
    }
    final uri = Uri.tryParse(supabaseUrl);
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        host != devSupabaseHost ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (path.isNotEmpty && path != '/')) {
      return 'Live E2E refuses SUPABASE_URL host "$host": only '
          'https://$devSupabaseHost (DEV) is allowed.';
    }
    if (!hasSupabaseAnonKey) {
      return 'Live E2E requires --dart-define=SUPABASE_ANON_KEY '
          '(the DEV publishable key).';
    }
    if (userEmail.isEmpty || userPassword.isEmpty) {
      return 'Live E2E requires E2E_USER_EMAIL and E2E_USER_PASSWORD.';
    }
    return null;
  }
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

  /// Only its presence is checked; the value is never read here or logged.
  static const bool hasSupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY') != '';

  static E2eMode get mode => _mode == 'live' ? E2eMode.live : E2eMode.mock;

  static Set<String> get requestedTags => {
    for (final tag in _tags.split(','))
      if (tag.trim().isNotEmpty) tag.trim(),
  };

  /// Returns why a live run must not start, or null when it may.
  ///
  /// Live E2E is DEV-only: it refuses any environment other than `dev` and
  /// any Supabase project other than DEV (see [E2eLiveGuard]).
  static String? liveModeProblem() => E2eLiveGuard.problem(
    appEnv: appEnv,
    supabaseUrl: supabaseUrl,
    hasSupabaseAnonKey: hasSupabaseAnonKey,
    userEmail: userEmail,
    userPassword: userPassword,
  );
}
