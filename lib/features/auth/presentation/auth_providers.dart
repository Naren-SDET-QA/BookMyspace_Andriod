import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthState, AuthUser;
import '../../../core/config/app_config.dart';
import '../../notifications/presentation/notification_providers.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';
import '../domain/phone_otp_provider.dart';
import '../infrastructure/development_phone_otp_provider.dart';
import '../infrastructure/supabase_phone_otp_provider.dart';
import '../../../core/notifications/onesignal_push_service.dart';
import '../domain/auth_configuration.dart';
import '../infrastructure/supabase_auth_configuration_repository.dart';
import '../infrastructure/supabase_auth_repository.dart';

/// Supabase client provider.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth repository provider.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError(
      'Initialize authRepositoryProvider in ProviderScope');
});

/// Phone OTP implementation selected without changing the login UI.
final phoneOtpProvider = Provider<PhoneOtpProvider>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  if (AppConfig.isTemporaryDevelopmentPhoneOtpEnabled) {
    return TemporaryDevelopmentPhoneOtpProvider();
  }
  return SupabasePhoneOtpProvider(repository);
});

/// Current auth user provider, derived from the canonical auth state.
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authNotifierProvider).user;
});

/// Auth state changes stream.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

/// StateNotifier managing authentication and triggering logout push cleanup.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._ref) : super(const AuthLoading()) {
    _init();
  }

  final AuthRepository _repository;
  final Ref _ref;
  StreamSubscription<AuthUser?>? _authSubscription;

  void _init() {
    _publishAuthState(_repository.currentUser);

    _authSubscription = _repository.authStateChanges().listen(
      _handleAuthEvent,
      onError: (Object _, StackTrace __) {
        // Keep the last known auth state when a transient auth-stream network
        // error occurs. The next Supabase auth event will reconcile it.
      },
    );
  }

  @override
  void dispose() {
    final subscription = _authSubscription;
    _authSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<AuthUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = await _repository.signInWithEmailPassword(email, password);
    if (mounted) _publishAuthState(user);
    return user;
  }

  Future<void> deleteAccount() async {
    state = const AuthLoading();
    try {
      try {
        final pushService = _ref.read(pushNotificationServiceProvider);
        await pushService.logoutCleanup();
      } catch (_) {}
      await _repository.deleteAccount();
      state = const AuthUnauthenticated();
    } catch (error) {
      final current = _repository.currentUser;
      state = current != null
          ? AuthAuthenticated(user: current)
          : const AuthUnauthenticated();
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AuthLoading();
    try {
      // Perform push notification cleanup before signing out
      try {
        final pushService = _ref.read(pushNotificationServiceProvider);
        await pushService.logoutCleanup();
      } catch (_) {}

      await _repository.signOut();
    } finally {
      if (mounted) _publishAuthState(_repository.currentUser);
    }
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    final updated = await _repository.updateProfile(
      fullName: fullName,
      avatarUrl: avatarUrl,
    );
    state = AuthAuthenticated(user: updated);
  }

  /// Applies only events that still describe the repository's current session.
  ///
  /// Supabase can deliver an auth event after the operation that caused it has
  /// completed. During a fast account switch, a queued SIGNED_OUT event can
  /// otherwise overwrite the next user's authenticated state and make the
  /// router tear down and rebuild the shell twice.
  void _handleAuthEvent(AuthUser? eventUser) {
    if (!_matchesCurrentSession(eventUser)) return;
    _publishAuthState(eventUser);
  }

  bool _matchesCurrentSession(AuthUser? eventUser) {
    final current = _repository.currentUser;
    return eventUser?.id == current?.id;
  }

  void _publishAuthState(AuthUser? user) {
    if (user == null) {
      if (state is AuthUnauthenticated) return;
      state = const AuthUnauthenticated();
      return;
    }

    final previous = state;
    if (previous is AuthAuthenticated &&
        previous.user.id == user.id &&
        previous.user.email == user.email &&
        previous.user.phone == user.phone &&
        previous.user.fullName == user.fullName &&
        previous.user.avatarUrl == user.avatarUrl &&
        previous.user.role == user.role &&
        previous.user.verificationStatus == user.verificationStatus) {
      return;
    }

    state = AuthAuthenticated(user: user);
    _syncPushToken();
  }

  void _syncPushToken() {
    try {
      final pushService = _ref.read(pushNotificationServiceProvider);
      final token = pushService.currentDeviceToken;
      if (token == null || token.isEmpty) return;
      unawaited(
        _ref
            .read(notificationRepositoryProvider)
            .registerPushToken(token, 'auto')
            .catchError((_) {}),
      );
    } catch (_) {}
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});

/// Initialises the Supabase client. Call once before runApp().
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
  );
}

/// Optionally establishes a real DEV Auth session for browser regression runs.
/// Credentials are supplied at launch and are never available in production.
Future<void> signInDevelopmentTestUser() async {
  if (!AppConfig.isDevelopment ||
      AppConfig.devTestEmail.isEmpty ||
      AppConfig.devTestPassword.isEmpty) {
    return;
  }
  final client = Supabase.instance.client;
  if (client.auth.currentSession != null) return;
  await client.auth.signInWithPassword(
    email: AppConfig.devTestEmail,
    password: AppConfig.devTestPassword,
  );
}

final authConfigurationRepositoryProvider = Provider((ref) {
  return SupabaseAuthConfigurationRepository(ref.watch(supabaseProvider));
});

final authConfigurationProvider = FutureProvider<AuthConfiguration>((ref) {
  return ref.watch(authConfigurationRepositoryProvider).load();
});

/// Emits when a recovery email deep-link establishes a session.
final passwordRecoveryProvider = StreamProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).passwordRecoveryState();
});
