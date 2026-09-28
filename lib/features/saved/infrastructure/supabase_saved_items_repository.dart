import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/saved_item.dart';

class SupabaseSavedItemsRepository implements SavedItemsRepository {
  SupabaseSavedItemsRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  bool _missingTable(Object e) =>
      e is PostgrestException && (e.code == '42P01' || e.code == 'PGRST205');

  Future<List<Map<String, dynamic>>> _rows(SavedItemType? type) async {
    final userId = _userId;
    if (userId == null) return const [];
    var q = _client
        .from('saved_items')
        .select('item_type, item_id, created_at')
        .eq('user_id', userId);
    if (type != null) q = q.eq('item_type', type.dbValue);
    final rows = await q.order('created_at', ascending: false);
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Future<Map<SavedItemType, Set<String>>> savedIds() async {
    try {
      final rows = await _rows(null);
      final out = {for (final t in SavedItemType.values) t: <String>{}};
      for (final row in rows) {
        final type = SavedItemType.values
            .where((t) => t.dbValue == row['item_type'])
            .firstOrNull;
        final id = row['item_id'] as String?;
        if (type != null && id != null) out[type]!.add(id);
      }
      return out;
    } catch (e) {
      if (_missingTable(e)) return const {};
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> save(SavedItemType type, String id) async {
    final userId = _userId;
    if (userId == null) {
      throw const app_errors.AuthException('Sign in to save.');
    }
    try {
      await _client.from('saved_items').upsert(
        {'user_id': userId, 'item_type': type.dbValue, 'item_id': id},
        onConflict: 'user_id,item_type,item_id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> unsave(SavedItemType type, String id) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _client
          .from('saved_items')
          .delete()
          .eq('user_id', userId)
          .eq('item_type', type.dbValue)
          .eq('item_id', id);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<SavedListing>> listings(SavedItemType type) async {
    try {
      final rows = await _rows(type);
      final ids = [for (final r in rows) r['item_id'] as String];
      if (ids.isEmpty) return const [];
      final byId = <String, SavedListing>{};
      switch (type) {
        case SavedItemType.course:
          final data = await _client
              .from('courses')
              .select('id, title, cover_image, institutes (name)')
              .inFilter('id', ids);
          for (final row in data.whereType<Map<String, dynamic>>()) {
            final institute = row['institutes'];
            byId[row['id'] as String] = SavedListing(
              type: type,
              id: row['id'] as String,
              title: row['title'] as String? ?? 'Course',
              subtitle: institute is Map ? '${institute['name'] ?? ''}' : '',
              imageUrl: row['cover_image'] as String? ?? '',
            );
          }
        case SavedItemType.institute:
          final data = await _client
              .from('institutes')
              .select('id, name, city, logo_image')
              .inFilter('id', ids);
          for (final row in data.whereType<Map<String, dynamic>>()) {
            byId[row['id'] as String] = SavedListing(
              type: type,
              id: row['id'] as String,
              title: row['name'] as String? ?? 'Institute',
              subtitle: row['city'] as String? ?? '',
              imageUrl: row['logo_image'] as String? ?? '',
            );
          }
      }
      // Keep saved order (newest first).
      return [for (final id in ids) if (byId[id] != null) byId[id]!];
    } catch (e) {
      if (_missingTable(e)) return const [];
      throw app_errors.mapError(e);
    }
  }
}
