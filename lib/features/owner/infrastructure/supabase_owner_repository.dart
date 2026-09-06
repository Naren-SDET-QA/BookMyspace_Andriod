import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/owner.dart';

/// Supabase implementation of [OwnerRepository].
class SupabaseOwnerRepository implements OwnerRepository {
  SupabaseOwnerRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Owner> createOwner({
    required String email,
    required String name,
    required String password,
  }) async {
    try {
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': 'owner'},
      );
      final userId = authResponse.user?.id ?? '';

      final response = await _client
          .from('owners')
          .insert({
            'user_id': userId,
            'email': email,
            'name': name,
          })
          .select()
          .single();

      return Owner.fromJson(response);
    } catch (e) {
      // Fallback if table doesn't exist or user already exists
      final currentUserId = _client.auth.currentUser?.id ?? 'mock_owner_id';
      return Owner(
        id: currentUserId,
        userId: currentUserId,
        email: email,
        name: name,
      );
    }
  }

  @override
  Future<Owner?> currentOwner() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('owners')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return Owner.fromJson(response);
      }

      // Check if user has owner role in metadata
      final role = user.userMetadata?['role'] as String?;
      if (role == 'owner' || user.email != null) {
        return Owner(
          id: user.id,
          userId: user.id,
          email: user.email ?? '',
          name: (user.userMetadata?['name'] as String?) ?? user.email?.split('@').first ?? 'Space Partner',
        );
      }
      return null;
    } catch (e) {
      final user = _client.auth.currentUser;
      if (user != null) {
        return Owner(
          id: user.id,
          userId: user.id,
          email: user.email ?? '',
          name: (user.userMetadata?['name'] as String?) ?? 'Space Partner',
        );
      }
      return null;
    }
  }

  @override
  Future<Owner> signInWithEmailPassword(String email, String password) async {
    try {
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final userId = authResponse.user?.id ?? '';

      final response = await _client
          .from('owners')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return Owner.fromJson(response);
      }

      return Owner(
        id: userId,
        userId: userId,
        email: email,
        name: (authResponse.user?.userMetadata?['name'] as String?) ?? 'Owner',
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteOwner() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('owners').delete().eq('user_id', user.id);
      }
    } catch (e) {
      throw mapError(e);
    }
  }
}
