import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/category_health.dart';

/// Counts active, non-deleted venues per `venue_categories.slug`, and how
/// many of them have at least one `venue_images` row. Read-only; uses the
/// existing venues -> venue_categories and venues -> venue_images relations.
class SupabaseCategoryListingStatsRepository
    implements CategoryListingStatsRepository {
  const SupabaseCategoryListingStatsRepository(this._client);

  final SupabaseClient _client;

  static const _pageSize = 1000;
  static const _maxRows = 10000;

  @override
  Future<Map<String, CategoryListingStats>> statsBySlug() async {
    try {
      final listings = <String, int>{};
      final withImages = <String, int>{};
      for (var from = 0; from < _maxRows; from += _pageSize) {
        final rows = await _client
            .from('venues')
            .select('id, venue_categories(slug), venue_images(id)')
            .eq('is_active', true)
            .isFilter('deleted_at', null)
            .order('id')
            .range(from, from + _pageSize - 1);
        for (final row in rows.whereType<Map<String, dynamic>>()) {
          final category = row['venue_categories'];
          final slug = category is Map ? category['slug']?.toString() : null;
          if (slug == null || slug.isEmpty) continue;
          listings[slug] = (listings[slug] ?? 0) + 1;
          final images = row['venue_images'];
          if (images is List && images.isNotEmpty) {
            withImages[slug] = (withImages[slug] ?? 0) + 1;
          }
        }
        if (rows.length < _pageSize) break;
      }
      return {
        for (final entry in listings.entries)
          entry.key: CategoryListingStats(
            listings: entry.value,
            withImages: withImages[entry.key] ?? 0,
          ),
      };
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
