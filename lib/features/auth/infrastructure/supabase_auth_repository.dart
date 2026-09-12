import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/errors/app_exceptions.dart' as errors;
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// Supabase-backed implementation of the application authentication contract.
///
/// The repository is deliberately kept behind [AuthRepository] so the
/// presentation layer remains independent of Supabase and can continue to use
/// test repositories in widget tests.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {this.isConfigured = true});

  /// Deep link registered in iOS URL schemes and the Android intent-filter.
  /// Must also be allow-listed in the Supabase Auth redirect URLs.
  static const oauthRedirectTo = 'bookmyspace://login-callback/';

  final supabase.SupabaseClient _client;
  final bool isConfigured;

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map(
      (state) => _mapUser(state.session?.user),
    );
  }

  @override
  Future<void> signInWithEmailOtp(String email) {
    _ensureConfigured();
    return _client.auth.signInWithOtp(email: email);
  }

  @override
  Future<AuthUser> verifyEmailOtp(String email, String token) async {
    _ensureConfigured();
    final response = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: supabase.OtpType.email,
    );
    return _requireUser(response.user ?? _client.auth.currentUser);
  }

  @override
  Future<AuthUser> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    _ensureConfigured();
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return _requireUser(response.user ?? _client.auth.currentUser);
    } on supabase.AuthException catch (error) {
      throw errors.AuthException(
        error.message,
        code: error.statusCode,
      );
    }
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) {
    _ensureConfigured();
    return _client.auth.signInWithOtp(phone: phone);
  }

  @override
  Future<AuthUser> verifyPhoneOtp(String phone, String token) async {
    _ensureConfigured();
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: supabase.OtpType.sms,
    );
    return _requireUser(response.user ?? _client.auth.currentUser);
  }

  @override
  Future<AuthUser> signInWithGoogle() {
    return _signInWithOAuth(supabase.OAuthProvider.google);
  }

  @override
  Future<AuthUser> signInWithApple() {
    return _signInWithOAuth(supabase.OAuthProvider.apple);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> signOutAllDevices() {
    _ensureConfigured();
    return _client.auth.signOut(scope: supabase.SignOutScope.global);
  }

  @override
  Future<void> deleteAccount() async {
    _ensureConfigured();
    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status >= 400) {
        throw errors.ServerException(
          'Account deletion failed. Please retry.',
          statusCode: response.status,
        );
      }
    } on supabase.FunctionException catch (error) {
      if (error.status == 401) {
        throw const errors.AuthException(
          'Your session expired. Sign in again to delete this account.',
          statusCode: 401,
        );
      }
      throw errors.ServerException(
        'Account deletion failed. Please retry.',
        statusCode: error.status,
      );
    }
    try {
      await _client.auth.signOut();
    } catch (_) {
      // The auth user is already deleted server-side.
    }
  }

  @override
  Future<AuthUser> updateProfile({String? fullName, String? avatarUrl}) async {
    _ensureConfigured();
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;

    final response = data.isEmpty
        ? null
        : await _client.auth.updateUser(supabase.UserAttributes(data: data));
    return _requireUser(response?.user ?? _client.auth.currentUser);
  }

  @override
  Future<void> refreshSession() async {
    _ensureConfigured();
    await _client.auth.refreshSession();
  }

  Future<AuthUser> _signInWithOAuth(supabase.OAuthProvider provider) async {
    _ensureConfigured();
    final label = _oauthLabel(provider);
    final signedIn = Completer<AuthUser>();
    late final StreamSubscription<supabase.AuthState> subscription;

    subscription = _client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event != supabase.AuthChangeEvent.signedIn ||
            state.session?.user == null ||
            signedIn.isCompleted) {
          return;
        }
        signedIn.complete(_requireUser(state.session!.user));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!signedIn.isCompleted) {
          signedIn.completeError(_mapOAuthError(error, label), stackTrace);
        }
      },
    );

    try {
      final launched = await _client.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : oauthRedirectTo,
      );
      if (!launched) {
        throw errors.AuthCancelledException('$label sign-in was cancelled.');
      }
      return await signedIn.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw errors.TimeoutException(
          '$label sign-in did not complete.',
        ),
      );
    } on errors.AppException {
      rethrow;
    } catch (error) {
      throw _mapOAuthError(error, label);
    } finally {
      await subscription.cancel();
    }
  }

  static String _oauthLabel(supabase.OAuthProvider provider) {
    switch (provider) {
      case supabase.OAuthProvider.google:
        return 'Google';
      case supabase.OAuthProvider.apple:
        return 'Apple';
      default:
        return provider.name;
    }
  }

  static Object _mapOAuthError(Object error, String label) {
    if (error is errors.AppException) return error;
    if (error is TimeoutException) {
      return errors.TimeoutException(
        error.message ?? '$label sign-in did not complete.',
      );
    }
    final message = error.toString().toLowerCase();
    if (message.contains('cancel') || message.contains('dismiss')) {
      return errors.AuthCancelledException('$label sign-in was cancelled.');
    }
    if (error is supabase.AuthException) {
      return errors.AuthException(error.message, code: error.code);
    }
    return errors.mapError(error);
  }

  static AuthUser? _mapUser(supabase.User? user) {
    if (user == null) return null;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      phone: user.phone ?? '',
      fullName: _firstString(metadata, const ['full_name', 'fullName', 'name']),
      avatarUrl: _firstString(
        metadata,
        const ['avatar_url', 'avatarUrl', 'picture'],
      ),
    );
  }

  static String _firstString(Map<String, dynamic> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return '';
  }

  static AuthUser _requireUser(supabase.User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) {
      throw StateError('Supabase authentication returned no user session.');
    }
    return mapped;
  }

  void _ensureConfigured() {
    if (isConfigured) return;
    throw StateError(
      'Supabase is not configured. Launch with '
      '--dart-define=SUPABASE_URL=<project-url> and '
      'either --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> '
      'or --dart-define=SUPABASE_ANON_KEY=<publishable-key>.',
    );
  }
}
