import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/registration_field_config.dart';

class SupabaseRegistrationConfigRepository {
  SupabaseRegistrationConfigRepository(this._client);
  final SupabaseClient _client;

  Future<List<RegistrationFieldConfig>> ownerFields() async {
    final rows = await _client
        .from('owner_registration_field_configs')
        .select('*')
        .eq('enabled', true)
        .eq('owner_visible', true)
        .order('display_order');
    return rows.map(RegistrationFieldConfig.fromJson).toList();
  }

  Future<List<RegistrationFieldConfig>> allFields() async {
    final rows = await _client
        .from('owner_registration_field_configs')
        .select('*')
        .order('display_order');
    return rows.map(RegistrationFieldConfig.fromJson).toList();
  }

  Future<void> saveOwnerValues(Map<String, String> values) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    await _client.from('owner_registration_values').upsert([
      for (final entry in values.entries)
        {
          'owner_user_id': userId,
          'field_key': entry.key,
          'value_text': entry.value,
        },
    ], onConflict: 'owner_user_id,field_key');
  }

  Future<void> updateFieldConfig(
    String fieldKey,
    Map<String, dynamic> changes,
  ) async {
    await _client
        .from('owner_registration_field_configs')
        .update(changes)
        .eq('field_key', fieldKey);
  }

  Future<RegistrationFieldConfig> saveField({
    required String key,
    required String label,
    String type = 'text',
    bool required = false,
    String? regexPattern,
    Map<String, dynamic> validationRules = const {},
    String? presetKey,
    int displayOrder = 0,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'admin_create_registration_field',
      params: {
        'p_field_key': key,
        'p_display_label': label,
        'p_field_type': type,
        'p_required': required,
        'p_regex_pattern': regexPattern,
        'p_validation_rules': validationRules,
        'p_preset_key': presetKey,
        'p_display_order': displayOrder,
      },
    );
    return RegistrationFieldConfig.fromJson(row);
  }

  Future<void> deleteField(String key) async {
    await _client.rpc<void>(
      'admin_delete_registration_field',
      params: {'p_field_key': key},
    );
  }

  Future<void> reorderFields(List<String> keys) async {
    await _client.rpc<void>(
      'admin_reorder_registration_fields',
      params: {'p_field_keys': keys},
    );
  }
}
