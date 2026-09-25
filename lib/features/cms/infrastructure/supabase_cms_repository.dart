import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart';
import '../domain/cms_banner.dart';

class SupabaseCmsRepository {
  SupabaseCmsRepository(this._client);

  final SupabaseClient _client;

  Future<List<CmsBanner>> listActiveBanners() async {
    try {
      final rows = await _client
          .from('cms_banners')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CmsBanner.fromJson)
          .toList();
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST205' || error.code == '42P01') {
        return const [];
      }
      throw mapError(error);
    }
  }

  Future<List<CmsBanner>> listAllBannersForAdmin() async {
    try {
      final rows =
          await _client.from('cms_banners').select().order('sort_order');
      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CmsBanner.fromJson)
          .toList();
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST205' || error.code == '42P01') {
        return const [];
      }
      throw mapError(error);
    }
  }

  Future<CmsBanner> upsertBanner(CmsBanner banner) async {
    final payload = banner.toWriteJson();
    final row = banner.id.isEmpty
        ? await _client.from('cms_banners').insert(payload).select().single()
        : await _client
            .from('cms_banners')
            .update(payload)
            .eq('id', banner.id)
            .select()
            .single();
    return CmsBanner.fromJson(Map<String, dynamic>.from(row as Map));
  }
}
