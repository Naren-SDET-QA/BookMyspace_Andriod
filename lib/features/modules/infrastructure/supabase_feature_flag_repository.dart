import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/feature_flag.dart';
import '../domain/feature_flag_repository.dart';

class SupabaseFeatureFlagRepository implements FeatureFlagRepository {
  SupabaseFeatureFlagRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      'key, enabled, platforms, config, updated_at, updated_by';

  @override
  Future<List<FeatureFlag>> listFlags() async {
    try {
      final rows =
          await _client.from('feature_flags').select(_select).order('key');
      return rows
          .whereType<Map<String, dynamic>>()
          .map(FeatureFlag.fromJson)
          .toList(growable: false);
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<FeatureFlag> saveFlag({
    required String key,
    required bool enabled,
    required List<String> platforms,
    required Map<String, dynamic> config,
  }) async {
    try {
      final row = await _client
          .from('feature_flags')
          .upsert(
            {
              'key': key,
              'enabled': enabled,
              'platforms': platforms,
              'config': config,
            },
            onConflict: 'key',
          )
          .select(_select)
          .single();
      return FeatureFlag.fromJson(row);
    } catch (error) {
      // A rejected RLS/config write is surfaced to the admin. The UI never
      // reports a local toggle as saved before this response arrives.
      throw app_errors.mapError(error);
    }
  }
}
