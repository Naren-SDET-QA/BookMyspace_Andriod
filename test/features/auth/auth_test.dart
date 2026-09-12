import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/auth/domain/auth_state.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_auth_repository.dart';

void main() {
  group('AuthUser', () {
    test('serializes and deserializes', () {
      const user = AuthUser(
        id: 'u1',
        email: 'a@b.com',
        phone: '9999999999',
        fullName: 'Alice',
        avatarUrl: 'https://img/avatar.png',
      );
      final json = user.toJson();
      final restored = AuthUser.fromJson(json);
      expect(restored.id, 'u1');
      expect(restored.fullName, 'Alice');
    });

    test('copyWith preserves unset fields', () {
      const user = AuthUser(id: 'u1', email: 'a@b.com');
      final updated = user.copyWith(fullName: 'Bob');
      expect(updated.email, 'a@b.com');
      expect(updated.fullName, 'Bob');
    });

    test('equality is id and email based', () {
      const a = AuthUser(id: 'u1', email: 'x@y.com');
      const b = AuthUser(id: 'u1', email: 'x@y.com', fullName: 'diff');
      expect(a, b);
    });
  });

  group('AuthState', () {
    test('discriminates state types', () {
      const unauth = AuthUnauthenticated();
      const auth = AuthAuthenticated(
        user: AuthUser(id: 'u1', email: 'x@y.com'),
      );
      const loading = AuthLoading();
      expect(unauth, isA<AuthUnauthenticated>());
      expect(auth, isA<AuthAuthenticated>());
      expect(auth.user.email, 'x@y.com');
      expect(loading, isA<AuthLoading>());
    });
  });

  group('MockAuthRepository', () {
    test('emits auth state changes on sign in/out', () async {
      final repo = MockAuthRepository();
      final events = <AuthUser?>[];
      final sub = repo.authStateChanges().listen(events.add);

      await repo.signInWithGoogle();
      await repo.signOut();

      expect(repo.currentUser, isNull);
      expect(events.length, 2);
      expect(events.last, isNull);
      await sub.cancel();
      repo.dispose();
    });

    test('verification creates a session', () async {
      final repo = MockAuthRepository();
      final user = await repo.verifyEmailOtp('a@b.com', '123456');
      expect(user.id, 'mock-user');
      expect(repo.currentUser?.email, 'a@b.com');
      repo.dispose();
    });

    test('surfaces failures without emitting sessions', () async {
      final repo = MockAuthRepository()..failGoogle = true;
      expect(repo.signInWithGoogle(), throwsException);
      expect(repo.currentUser, isNull);
      repo.dispose();
    });

    test('Google and Apple cancellation does not create a session', () async {
      final googleRepo = MockAuthRepository()..cancelGoogle = true;
      expect(
        googleRepo.signInWithGoogle(),
        throwsA(isA<AuthCancelledException>()),
      );
      expect(googleRepo.currentUser, isNull);
      googleRepo.dispose();

      final appleRepo = MockAuthRepository()..cancelApple = true;
      expect(
        appleRepo.signInWithApple(),
        throwsA(isA<AuthCancelledException>()),
      );
      expect(appleRepo.currentUser, isNull);
      appleRepo.dispose();
    });

    test('OTP send failures do not affect Google or Apple', () async {
      final repo = MockAuthRepository()..failSignIn = true;
      await repo.signInWithGoogle();
      expect(repo.currentUser?.email, 'mock@test.com');
      await repo.signOut();
      await repo.signInWithApple();
      expect(repo.currentUser?.email, 'mock@test.com');
      expect(repo.signInCount, 0);
      expect(repo.googleCount, 1);
      expect(repo.appleCount, 1);
      repo.dispose();
    });

    test('maintains cross-user state isolation during transitions', () async {
      final repo = MockAuthRepository();
      // Anonymous -> User A
      final userA = await repo.verifyEmailOtp('userA@test.com', '111111');
      expect(repo.currentUser?.id, userA.id);
      expect(repo.currentUser?.email, 'userA@test.com');

      // User A -> Logout
      await repo.signOut();
      expect(repo.currentUser, isNull);

      // User A -> Logout -> User B
      final userB = await repo.verifyEmailOtp('userB@test.com', '222222');
      expect(repo.currentUser?.id, userB.id);
      expect(repo.currentUser?.email, 'userB@test.com');
      expect(repo.currentUser?.email, isNot(equals('userA@test.com')));

      // Final cleanup
      await repo.signOut();
      expect(repo.currentUser, isNull);
      repo.dispose();
    });
  });
}
