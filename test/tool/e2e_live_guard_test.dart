import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/e2e_env.dart';

/// Live E2E must only ever reach the DEV Supabase project.
void main() {
  const devUrl = 'https://zykxneztahxbjduagutv.supabase.co';
  const fakePassword = 'fake-fake-fake-fake';

  String? problem({
    String appEnv = 'dev',
    String supabaseUrl = devUrl,
    bool hasSupabaseAnonKey = true,
    String userEmail = 'customer@guard.test',
    String userPassword = fakePassword,
  }) => E2eLiveGuard.problem(
    appEnv: appEnv,
    supabaseUrl: supabaseUrl,
    hasSupabaseAnonKey: hasSupabaseAnonKey,
    userEmail: userEmail,
    userPassword: userPassword,
  );

  test('allows only the DEV project with every setting present', () {
    expect(E2eLiveGuard.devSupabaseHost, 'zykxneztahxbjduagutv.supabase.co');
    expect(problem(), isNull);
    expect(problem(supabaseUrl: '$devUrl/'), isNull);
  });

  test('refuses any environment other than dev', () {
    for (final env in ['', 'prod', 'production', 'staging', 'development']) {
      expect(problem(appEnv: env), contains('APP_ENV=dev'), reason: env);
    }
  });

  test('refuses every non-DEV Supabase URL', () {
    const urls = [
      'https://abcdefghijklmnopqrst.supabase.co',
      'http://zykxneztahxbjduagutv.supabase.co',
      'https://zykxneztahxbjduagutv.supabase.co.example.test',
      'https://example.test/zykxneztahxbjduagutv.supabase.co',
      'https://zykxneztahxbjduagutv.supabase.co:8443',
      'https://user@zykxneztahxbjduagutv.supabase.co',
      'https://zykxneztahxbjduagutv.supabase.co/rest/v1',
      'https://zykxneztahxbjduagutv.supabase.co?ref=prod',
      'http://127.0.0.1:54321',
      'zykxneztahxbjduagutv.supabase.co',
    ];
    for (final url in urls) {
      expect(
        problem(supabaseUrl: url),
        contains('refuses SUPABASE_URL'),
        reason: url,
      );
    }
  });

  test('fails clearly when a required setting is missing', () {
    expect(problem(supabaseUrl: ''), contains('SUPABASE_URL'));
    expect(problem(hasSupabaseAnonKey: false), contains('SUPABASE_ANON_KEY'));
    expect(problem(userEmail: ''), contains('E2E_USER_EMAIL'));
    expect(problem(userPassword: ''), contains('E2E_USER_PASSWORD'));
  });

  test('never echoes a credential value', () {
    final messages = [
      problem(appEnv: 'prod'),
      problem(supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co'),
      problem(hasSupabaseAnonKey: false),
      problem(userEmail: ''),
    ];
    for (final message in messages) {
      expect(message, isNotNull);
      expect(message, isNot(contains(fakePassword)));
      expect(message, isNot(contains('customer@guard.test')));
    }
  });
}
