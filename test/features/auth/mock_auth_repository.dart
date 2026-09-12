import 'dart:async';

import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/auth/domain/auth_repository.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';

/// In-memory mock used for unit tests and widget tests.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({AuthUser? initialUser}) : _user = initialUser {
    _controller = StreamController<AuthUser?>.broadcast();
  }

  AuthUser? _user;
  late final StreamController<AuthUser?> _controller;

  /// Overridable behaviours for test scenarios.
  bool failSignIn = false;
  bool failVerify = false;
  bool failSignOut = false;
  bool cancelGoogle = false;
  bool cancelApple = false;
  bool failGoogle = false;
  bool failApple = false;
  Completer<AuthUser>? delayedGoogle;
  Completer<AuthUser>? delayedApple;
  int signInCount = 0;
  int googleCount = 0;
  int appleCount = 0;
  int verifyCount = 0;
  int deleteAccountCount = 0;
  bool failDeleteAccount = false;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> signInWithApple() async {
    appleCount++;
    if (cancelApple) {
      throw const AuthCancelledException('Apple sign-in was cancelled.');
    }
    if (failApple) {
      throw Exception('Apple sign-in failed');
    }
    if (delayedApple != null) {
      return _completeSocial(await delayedApple!.future);
    }
    return _completeSocial();
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    googleCount++;
    if (cancelGoogle) {
      throw const AuthCancelledException('Google sign-in was cancelled.');
    }
    if (failGoogle) {
      throw Exception('Google sign-in failed');
    }
    if (delayedGoogle != null) {
      return _completeSocial(await delayedGoogle!.future);
    }
    return _completeSocial();
  }

  @override
  Future<void> signInWithEmailOtp(String email) async {
    signInCount++;
    if (failSignIn) {
      throw Exception('OTP send failed');
    }
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) async {
    signInCount++;
    if (failSignIn) {
      throw Exception('OTP send failed');
    }
  }

  Future<AuthUser> _completeSocial([AuthUser? user]) async {
    _user = user ??
        const AuthUser(
          id: 'mock-user',
          email: 'mock@test.com',
          fullName: 'Mock User',
        );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    signInCount++;
    if (failSignIn) {
      throw Exception('Password sign-in failed');
    }
    _user = AuthUser(id: 'mock-user', email: email, fullName: 'Mock User');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> verifyEmailOtp(String email, String token) async {
    verifyCount++;
    if (failVerify) {
      throw Exception('Invalid OTP');
    }
    _user = AuthUser(id: 'mock-user', email: email, fullName: 'Mock User');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<AuthUser> verifyPhoneOtp(String phone, String token) async {
    verifyCount++;
    if (failVerify) {
      throw Exception('Invalid OTP');
    }
    _user = AuthUser(id: 'mock-user', phone: phone, fullName: 'Mock User');
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) {
      throw Exception('Sign out failed');
    }
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> signOutAllDevices() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCount++;
    if (failDeleteAccount) {
      throw const AuthException('Account deletion failed.');
    }
    _user = null;
    _controller.add(null);
  }

  @override
  Future<AuthUser> updateProfile({String? fullName, String? avatarUrl}) async {
    _user = (_user ?? const AuthUser(id: 'mock-user')).copyWith(
      fullName: fullName,
      avatarUrl: avatarUrl,
    );
    _controller.add(_user);
    return _user!;
  }

  @override
  Future<void> refreshSession() async {}

  void dispose() => _controller.close();
}
