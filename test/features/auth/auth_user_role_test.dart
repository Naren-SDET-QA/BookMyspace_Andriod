import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/infrastructure/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

User _makeUser({
  Map<String, dynamic> appMetadata = const {},
  Map<String, dynamic>? userMetadata,
}) {
  return User(
    id: 'u1',
    appMetadata: appMetadata,
    userMetadata: userMetadata,
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  test('preserves customer role and unverified status', () {
    const user = AuthUser(id: 'customer');

    expect(user.role, AppRole.customer);
    expect(user.verificationStatus, VerificationStatus.unknown);
    expect(user.isAdmin, isFalse);
    expect(user.isOwner, isFalse);
  });

  test('preserves venue owner and approved verification', () {
    const user = AuthUser(
      id: 'owner',
      role: AppRole.venueOwner,
      verificationStatus: VerificationStatus.approved,
    );

    expect(user.isOwner, isTrue);
    expect(user.isAdmin, isFalse);
    expect(user.verificationStatus, VerificationStatus.approved);
  });

  test('preserves admin role and elevated access', () {
    const user = AuthUser(
      id: 'admin',
      role: AppRole.admin,
      verificationStatus: VerificationStatus.approved,
    );

    expect(user.isAdmin, isTrue);
    expect(user.isOwner, isTrue);
  });

  group('SupabaseAuthRepository metadata role hydration', () {
    test('owner metadata -> initial owner role', () {
      for (final role in ['venue_owner', 'institute_owner', 'event_organizer', 'VENUE_OWNER']) {
        final uApp = _makeUser(appMetadata: {'role': role});
        expect(
          SupabaseAuthRepository.roleFromMetadataForTesting(uApp),
          AppRole.venueOwner,
          reason: 'app_metadata role  should map to venueOwner',
        );

        final uUser = _makeUser(userMetadata: {'role': role});
        expect(
          SupabaseAuthRepository.roleFromMetadataForTesting(uUser),
          AppRole.venueOwner,
          reason: 'user_metadata role  should map to venueOwner',
        );
      }
    });

    test('admin metadata -> initial admin role', () {
      for (final role in ['admin', 'administrator', 'super_administrator', 'ADMIN']) {
        final uApp = _makeUser(appMetadata: {'role': role});
        expect(
          SupabaseAuthRepository.roleFromMetadataForTesting(uApp),
          AppRole.admin,
          reason: 'app_metadata role  should map to admin',
        );

        final uUser = _makeUser(userMetadata: {'role': role});
        expect(
          SupabaseAuthRepository.roleFromMetadataForTesting(uUser),
          AppRole.admin,
          reason: 'user_metadata role  should map to admin',
        );
      }
    });

    test('unknown/missing metadata -> customer', () {
      expect(
        SupabaseAuthRepository.roleFromMetadataForTesting(_makeUser()),
        AppRole.customer,
      );
      expect(
        SupabaseAuthRepository.roleFromMetadataForTesting(
          _makeUser(appMetadata: {'role': 'customer'}),
        ),
        AppRole.customer,
      );
      expect(
        SupabaseAuthRepository.roleFromMetadataForTesting(
          _makeUser(appMetadata: {'role': 'member'}),
        ),
        AppRole.customer,
      );
    });

    test('authoritative DB role overrides metadata in AuthUser', () {
      // User initially constructed with owner metadata
      final initialUser = AuthUser(
        id: 'u1',
        email: 'owner@test.com',
        role: SupabaseAuthRepository.roleFromMetadataForTesting(
          _makeUser(appMetadata: {'role': 'venue_owner'}),
        ),
      );
      expect(initialUser.isOwner, isTrue);

      // When authoritative DB lookup returns customer (e.g. revoked), DB role overrides
      final authoritativeUser = initialUser.copyWith(role: AppRole.customer);
      expect(authoritativeUser.isOwner, isFalse);
      expect(authoritativeUser.role, AppRole.customer);
    });
  });
}
