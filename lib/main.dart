import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/config/settings_controller.dart';
import 'core/offline/offline_providers.dart';
import 'core/offline/preferences_offline_store.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/booking/domain/booking_reminder_scheduler.dart';
import 'features/owner/infrastructure/supabase_owner_repository.dart';
import 'core/health/app_health.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push notifications (OneSignal) are admin-controlled: nothing is
  // initialised here. BookMySpaceApp calls
  // OneSignalPushService.instance.setEnabled(...) once Admin settings ->
  // Push Notifications / OneSignal has loaded, and only initialises the SDK
  // when that switch is ON and ONESIGNAL_APP_ID is configured.

  // Initialize Supabase
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

  runApp(
    ProviderScope(
      overrides: [
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
