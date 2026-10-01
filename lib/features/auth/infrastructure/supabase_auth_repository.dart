import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/errors/app_exceptions.dart' as errors;
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart' show AppException, mapError;
import '../domain/auth_user.dart' as domain;

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

  /// Coarse role / verification loaded from `user_roles` (release/v1.0
  /// route gating), cached per user so [currentUser] stays synchronous.
  final Map<String, (UserRole, VerificationStatus)> _hydrated = {};

  @override
  AuthUser? get currentUser => _withHydration(_mapUser(_client.auth.currentUser));

  AuthUser? _withHydration(AuthUser? user) {
    if (user == null) return null;
    final cached = _hydrated[user.id];
    if (cached == null) return user;
    return user.copyWith(role: cached.$1, verificationStatus: cached.$2);
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncExpand((state) async* {
      final sessionUser = state.session?.user;
      final mapped = _withHydration(_mapUser(sessionUser));
      yield mapped;
      if (sessionUser == null || mapped == null) return;
      // Then publish the authoritative coarse role from the database.
      final loaded = await _loadAuthoritativeUser(sessionUser);
      _hydrated[mapped.id] = (loaded.role, loaded.verificationStatus);
      if (loaded.role != mapped.role ||
          loaded.verificationStatus != mapped.verificationStatus) {
        yield mapped.copyWith(
          role: loaded.role,
          verificationStatus: loaded.verificationStatus,
        );
      }
    });
  }

  @override
  Future<void> signInWithEmailOtp(String email) {
    _ensureConfigured();
    return _client.auth.signInWithOtp(
      email: email,
      // OTP email templates can also contain a magic link. Configure the
      // native callback so either form returns to the app and lets the
      // Supabase SDK restore the session before routing.
      emailRedirectTo: kIsWeb ? null : oauthRedirectTo,
    );
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
      final raw = error.message.toLowerCase();
      if (raw.contains('provider is not enabled') ||
          raw.contains('unsupported provider')) {
        return errors.AuthException(
          '$label sign-in is not available right now. Please try another '
          'sign-in method or contact support.',
          code: error.code ?? 'provider_disabled',
        );
      }
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

  // --- merged from release/v1.0 ---
  @override
  Future<domain.AuthUser> signInWithPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw const AppAuthException('Login failed.');
      return _toUser(user);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb
            ? AppConfig.passwordResetRedirectUri
            : AppConfig.nativeAuthRedirectUri,
      );
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Stream<bool> passwordRecoveryState() {
    return _client.auth.onAuthStateChange
        .where(
          (data) =>
              data.event == AuthChangeEvent.passwordRecovery ||
              data.event == AuthChangeEvent.signedOut,
        )
        .map((data) => data.event == AuthChangeEvent.passwordRecovery);
  }

  @override
  Future<domain.AuthUser> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? _webRedirect() : AppConfig.nativeAuthRedirectUri,
      );
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppAuthException('Apple sign-in was not completed.');
      }
      return _toUser(user);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  static domain.UserRole _roleFromMetadata(User u) {
    final raw = u.appMetadata['role'] ?? u.userMetadata?['role'];
    if (raw is String) {
      return switch (raw.toLowerCase()) {
        'admin' || 'administrator' || 'super_administrator' =>
          domain.UserRole.admin,
        'venue_owner' || 'institute_owner' || 'event_organizer' =>
          domain.UserRole.venueOwner,
        _ => domain.UserRole.customer,
      };
    }
    return domain.UserRole.customer;
  }

  @visibleForTesting
  static domain.UserRole roleFromMetadataForTesting(User u) =>
      _roleFromMetadata(u);

  domain.AuthUser _toUser(User u) {
    return domain.AuthUser(
      id: u.id,
      email: u.email ?? '',
      phone: u.phone ?? '',
      fullName: (u.userMetadata?['full_name'] ?? '') as String,
      avatarUrl: (u.userMetadata?['avatar_url'] ?? '') as String,
      role: _roleFromMetadata(u),
    );
  }

  @visibleForTesting
  domain.AuthUser toUserForTesting(User u) => _toUser(u);

  Future<domain.AuthUser> _loadAuthoritativeUser(User user) async {
    var profile = <String, dynamic>{};
    var role = domain.UserRole.customer;
    var verification = user.emailConfirmedAt != null
        ? domain.VerificationStatus.approved
        : domain.VerificationStatus.pending;
    try {
      final profileRow = await _client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      profile = profileRow ?? profile;
      final roleRows = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .isFilter('revoked_at', null);
      final roles = roleRows.map((row) => row['role'] as String? ?? '').toSet();
      if (roles.contains('administrator') ||
          roles.contains('super_administrator')) {
        role = domain.UserRole.admin;
        verification = domain.VerificationStatus.approved;
      } else if (roles.any(
        (value) =>
            value == 'venue_owner' ||
            value == 'institute_owner' ||
            value == 'event_organizer',
      )) {
        role = domain.UserRole.venueOwner;
        final owner = await _client
            .from('owner_profiles')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();
        if (owner != null) {
          final organization = await _client
              .from('organizations')
              .select('business_verification')
              .eq('owner_user_id', owner['id'] as Object)
              .maybeSingle();
          verification = domain.VerificationStatus.values.firstWhere(
            (status) => status.name == organization?['business_verification'],
            orElse: () => domain.VerificationStatus.pending,
          );
        }
      }
    } catch (_) {
      // Keep the authenticated user usable if optional profile hydration is
      // unavailable; protected screens still require the authoritative role.
    }
    return domain.AuthUser(
      id: user.id,
      email: user.email ?? '',
      phone: user.phone ?? '',
      fullName:
          profile['full_name'] as String? ??
          (user.userMetadata?['full_name'] as String? ?? ''),
      avatarUrl:
          profile['avatar_url'] as String? ??
          (user.userMetadata?['avatar_url'] as String? ?? ''),
      role: role,
      verificationStatus: verification,
    );
  }

  String _webRedirect() {
    return AppConfig.webAuthRedirectUri;
  }
}

/// A Supabase authentication error surfaced to the presentation layer.
class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.code});
}
