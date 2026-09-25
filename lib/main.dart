import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/settings_controller.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/preferences_offline_store.dart';
import 'features/auth/infrastructure/supabase_auth_repository.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/booking/domain/booking_reminder_scheduler.dart';
import 'features/owner/infrastructure/supabase_owner_repository.dart';
import 'core/health/app_health.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final summary = AppConfig.environmentSummary;
  debugPrint('BookMySpace config: $summary');

  if (!AppConfig.isSupabaseConfigured || AppConfig.isPlaceholderSupabaseHost) {
    runApp(const _MissingSupabaseConfigApp());
    return;
  }

  // Push notifications (OneSignal) are admin-controlled: nothing is
  // initialised here. BookMySpaceApp calls
  // OneSignalPushService.instance.setEnabled(...) once Admin settings ->
  // Push Notifications / OneSignal has loaded, and only initialises the SDK
  // when that switch is ON and ONESIGNAL_APP_ID is configured.

  // Initialize Supabase (PKCE auth flow, session detection from deep links).
  await initSupabase();
  try {
    await SupabaseOwnerRepository(
      Supabase.instance.client,
    ).completePendingOwnerRegistration();
  } catch (error) {
    debugPrint('Pending owner registration could not be completed: $error');
  }
  // Optional, explicitly supplied DEV-only account for live regression.
  // Without these dart-defines the normal login/bypass behavior is unchanged.
  try {
    await signInDevelopmentTestUser();
  } catch (error) {
    debugPrint('DEV test sign-in unavailable: $error');
  }

  final authRepository = SupabaseAuthRepository(
    Supabase.instance.client,
    isConfigured: AppConfig.isSupabaseConfigured,
  );

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        offlineStoreProvider.overrideWithValue(
          PreferencesOfflineStore(Preferences(const FlutterSecureStorage())),
        ),
        localReminderGatewayProvider.overrideWithValue(
          FlutterLocalReminderGateway(),
        ),
      ],
      child: const BookMySpaceApp(),
    ),
  );
  // Health is deliberately started after the first frame boundary and is
  // never awaited by startup or allowed to prevent UI rendering.
  unawaited(_scanAppHealth());
}

Future<void> _scanAppHealth() async {
  final container = ProviderContainer();
  try {
    await container.read(appHealthProvider.future);
  } finally {
    container.dispose();
  }
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
