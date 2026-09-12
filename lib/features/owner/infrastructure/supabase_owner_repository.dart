import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/owner.dart';

/// Supabase implementation of [OwnerRepository].
///
/// Owner access is based on the deployed `owner_profiles` and
/// `organizations` tables. It never treats a signed-in email or user metadata
/// as proof of an owner role and never returns synthetic profiles.
class SupabaseOwnerRepository implements OwnerRepository {
  SupabaseOwnerRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Owner> createOwner({
    required String email,
    required String name,
    required String password,
    String? legalName,
    String? gstin,
    String? pan,
    String? city,
    String? state,
  }) async {
    try {
      final authResponse = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      final user = authResponse.user;
      if (user == null) {
        throw const app_errors.AuthException(
          'Owner registration did not create an authenticated user.',
        );
      }
      if (authResponse.session == null) {
        throw const app_errors.AuthException(
          'Confirm your email, then sign in before creating an owner profile.',
        );
      }

      // Role assignment is owned by the deployed SECURITY DEFINER function.
      // Flutter must not write user_roles directly or infer authorization from
      // auth metadata.
      final ownerId = await _client.rpc<String>(
        'complete_owner_registration',
        params: {'p_name': name.trim()},
      );

      final profile = await _client
          .from('owner_profiles')
          .select('id, user_id, email, name')
          .eq('id', ownerId)
          .single();

      await _ensureOrganization(user.id, name.trim());
      await _persistBusinessDetails(
        userId: user.id,
        legalName: legalName,
        gstin: gstin,
        pan: pan,
        city: city,
        state: state,
      );
      return Owner.fromJson(profile);
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<Owner?> currentOwner() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await _client
          .from('owner_profiles')
          .select('id, user_id, email, name')
          .eq('user_id', user.id)
          .maybeSingle();
      return profile == null ? null : Owner.fromJson(profile);
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<Owner> signInWithEmailPassword(String email, String password) async {
    try {
      final authResponse = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = authResponse.user;
      if (user == null) {
        throw const app_errors.AuthException('Sign-in returned no user.');
      }

      final profile = await _client
          .from('owner_profiles')
          .select('id, user_id, email, name')
          .eq('user_id', user.id)
          .maybeSingle();
      if (profile == null) {
        // Do not leave a customer authenticated through an owner-only flow.
        await _client.auth.signOut();
        throw const app_errors.AuthException(
          'This account is not registered as a BookMySpace owner.',
        );
      }
      return Owner.fromJson(profile);
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<void> deleteOwner() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }

    try {
      await _client.from('owner_profiles').delete().eq('user_id', user.id);
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  Future<void> _ensureOrganization(String userId, String ownerName) async {
    final existing = await _client
        .from('organizations')
        .select('id')
        .eq('owner_user_id', userId)
        .isFilter('deleted_at', null)
        .limit(1)
        .maybeSingle();
    if (existing != null) return;

    await _client.from('organizations').insert({
      'owner_user_id': userId,
      'org_type': 'venue_owner',
      'name': '$ownerName Spaces',
    });
  }

  Future<void> _persistBusinessDetails({
    required String userId,
    String? legalName,
    String? gstin,
    String? pan,
    String? city,
    String? state,
  }) async {
    final patch = <String, dynamic>{};
    void put(String key, String? value) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) patch[key] = trimmed;
    }

    put('legal_name', legalName);
    put('gstin', gstin);
    put('pan', pan);
    put('city', city);
    put('state', state);
    if (gstin != null && gstin.trim().isNotEmpty) {
      patch['business_verification'] = 'submitted';
    }
    if (pan != null && pan.trim().isNotEmpty) {
      patch['identity_verification'] = 'submitted';
    }
    if (patch.isEmpty) return;

    await _client
        .from('organizations')
        .update(patch)
        .eq('owner_user_id', userId)
        .isFilter('deleted_at', null);
  }
}
