import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDeveloperPlatformRepository {
  SupabaseDeveloperPlatformRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> apiKeys() async {
    final rows = await _client
        .from('developer_api_keys')
        .select('id,name,key_prefix,scopes,created_at,last_used_at,revoked_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createKey(
    String name,
    List<String> scopes,
  ) async {
    final value = await _client.rpc(
      'admin_create_developer_api_key',
      params: {'p_name': name, 'p_scopes': scopes},
    );
    return Map<String, dynamic>.from(value as Map);
  }

  Future<void> revokeKey(String id) async {
    await _client.rpc(
      'admin_revoke_developer_api_key',
      params: {'p_key_id': id},
    );
  }

  Future<List<Map<String, dynamic>>> endpoints() async {
    final rows = await _client
        .from('outbound_webhook_endpoints')
        .select(
          'id,name,endpoint_url,secret_reference,event_types,enabled,created_at,last_success_at',
        )
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveEndpoint({
    String? id,
    required String name,
    required String endpointUrl,
    required String secretReference,
    required List<String> eventTypes,
    required bool enabled,
  }) async {
    await _client.rpc(
      'admin_save_webhook_endpoint',
      params: {
        'p_id': id,
        'p_name': name,
        'p_endpoint_url': endpointUrl,
        'p_secret_reference': secretReference,
        'p_event_types': eventTypes,
        'p_enabled': enabled,
      },
    );
  }

  Future<List<Map<String, dynamic>>> deliveries() async {
    final rows = await _client
        .from('outbound_webhook_deliveries')
        .select(
          'id,endpoint_id,event_type,status,attempt_count,response_status,error_code,created_at,delivered_at',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }
}
