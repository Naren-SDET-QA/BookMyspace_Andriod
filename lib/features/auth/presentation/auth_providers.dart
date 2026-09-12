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
    final current = _repository.currentUser;
    if (current != null) {
      state = AuthAuthenticated(user: current);
    } else {
      state = const AuthUnauthenticated();
    }

    _authSubscription = _repository.authStateChanges().listen(
      (user) {
        if (user != null) {
          state = AuthAuthenticated(user: user);
          // Sync push token with backend when authenticated
          try {
            final pushService = _ref.read(pushNotificationServiceProvider);
            final token = pushService.currentDeviceToken;
            if (token != null && token.isNotEmpty) {
              _ref
                  .read(notificationRepositoryProvider)
                  .registerPushToken(token, 'auto');
            }
          } catch (_) {}
        } else {
          state = const AuthUnauthenticated();
        }
      },
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
    state = AuthAuthenticated(user: user);
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
      state = const AuthUnauthenticated();
    }
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    final updated = await _repository.updateProfile(
      fullName: fullName,
      avatarUrl: avatarUrl,
    );
    state = AuthAuthenticated(user: updated);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});
