import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'features/auth/infrastructure/supabase_auth_repository.dart';
import 'features/auth/presentation/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final summary = AppConfig.environmentSummary;
  debugPrint('BookMySpace config: $summary');

  if (!AppConfig.isSupabaseConfigured || AppConfig.isPlaceholderSupabaseHost) {
    runApp(const _MissingSupabaseConfigApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    // Keep redirect-based Auth flows on the current PKCE flow explicitly.
    // This is the secure default in current supabase_flutter releases and
    // makes the callback/session contract clear for mobile deep links.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  final authRepository = SupabaseAuthRepository(
    Supabase.instance.client,
    isConfigured: AppConfig.isSupabaseConfigured,
  );

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
      child: BookMySpaceApp(),
    ),
  );
}

/// Shown when the binary was built without real `--dart-define` values.
///
/// Prevents the app from calling `your_project.supabase.co`.
class _MissingSupabaseConfigApp extends StatelessWidget {
  const _MissingSupabaseConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'BookMySpace is missing hosted Supabase configuration.\n\n'
                'Rebuild with --dart-define-from-file=.env.dev so the app '
                'uses the real project host instead of a placeholder.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
