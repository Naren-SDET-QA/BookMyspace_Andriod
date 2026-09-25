import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../../core/theme/app_theme_config.dart';
import '../domain/app_theme_config_snapshot.dart';

class SupabaseAppThemeRepository {
  SupabaseAppThemeRepository(this._client);

  final SupabaseClient _client;

  Future<AppThemeConfig> getPublished() async {
    try {
      final value = await _client.rpc('get_published_app_theme_config');
      return AppThemeConfig.fromJson(value);
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  Future<AppThemeConfigSnapshot> getAdminSnapshot() async {
    try {
      final value = await _client.rpc('get_admin_app_theme_config');
      return AppThemeConfigSnapshot.fromJson(_map(value));
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  Future<AppThemeConfigSnapshot> saveDraft(AppThemeConfig config) async {
    try {
      final value = await _client.rpc(
        'save_app_theme_draft',
        params: {'p_config': config.toJson()},
      );
      return AppThemeConfigSnapshot.fromJson(_map(value));
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  Future<AppThemeConfigSnapshot> publish() async {
    try {
      final value = await _client.rpc('publish_app_theme_config');
      return AppThemeConfigSnapshot.fromJson(_map(value));
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Theme configuration response was not JSON.');
  }
}
