import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDailyReportRepository {
  SupabaseDailyReportRepository(this._client);

  final SupabaseClient _client;

  Future<bool> enabled() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('daily_report_preferences')
        .select('enabled')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['enabled'] as bool? ?? false;
  }

  Future<void> save({required bool enabled}) async {
    await _client.rpc<void>(
      'save_daily_report_preference',
      params: {
        'p_enabled': enabled,
        // The app's existing Indian venue/account default. The schema accepts
        // any IANA timezone for future account settings surfaces.
        'p_timezone': 'Asia/Kolkata',
      },
    );
  }
}
