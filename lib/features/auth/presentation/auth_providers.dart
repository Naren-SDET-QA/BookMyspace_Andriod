import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../notifications/presentation/notification_providers.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';

/// Supabase client provider.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth repository provider.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('Initialize authRepositoryProvider in ProviderScope');
});

/// Current auth user provider.
final currentUserProvider = StateProvider<AuthUser?>((ref) {
  return null;
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

  void _init() {
    final current = _repository.currentUser;
    if (current != null) {
      state = AuthAuthenticated(user: current);
    } else {
      state = const AuthUnauthenticated();
    }

    _repository.authStateChanges().listen((user) {
      if (user != null) {
        state = AuthAuthenticated(user: user);
        // Sync push token with backend when authenticated
        try {
          final pushService = _ref.read(pushNotificationServiceProvider);
          final token = pushService.currentDeviceToken;
          if (token != null && token.isNotEmpty) {
            _ref.read(notificationRepositoryProvider).registerPushToken(token, 'auto');
          }
        } catch (_) {}
      } else {
        state = const AuthUnauthenticated();
      }
    });
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
