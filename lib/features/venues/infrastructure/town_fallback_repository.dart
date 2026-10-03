import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/venue.dart';

/// Venues shown when a search for a town returns nothing: the town is matched
/// against the India location hierarchy and the search widens to its parent
/// district, then state, until venues are found.
class TownFallback {
  const TownFallback({
    required this.townName,
    required this.scopeName,
    required this.scopeLevel,
    required this.venues,
  });

  /// The place the customer typed, as named in the location hierarchy.
  final String townName;

  /// The area the venues were found in (the town itself, its district, ...).
  final String scopeName;

  /// `city_town`, `area_locality`, `district_county` or `state_province`.
  final String scopeLevel;

  final List<Venue> venues;

  /// True when the venues are in the town itself, not a wider area.
  bool get inTown => scopeName == townName;

  /// Human label for [scopeLevel] ("district", "state"), empty for towns.
  String get scopeLabel => switch (scopeLevel) {
    'district_county' => 'district',
    'state_province' => 'state',
    _ => '',
  };
}

class TownFallbackRepository {
  TownFallbackRepository(this._client);

  final SupabaseClient _client;

  static const _venueSelect = '''
    *,
    venue_categories (id, slug, name, icon, metadata, parent_section, is_active, description, image_url),
    venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order, media_kind),
    venue_facilities (facility, is_available)
  ''';

  static const _venueSelectWithCategory = '''
    *,
    venue_categories!inner (id, slug, name, icon, metadata, parent_section, is_active, description, image_url),
    venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order, media_kind),
    venue_facilities (facility, is_available)
  ''';

  /// Preferred match when several places share a name.
  static const _levelPriority = [
    'city_town',
    'area_locality',
    'district_county',
    'state_province',
  ];

  /// Returns null when [text] is not a known place name or no venue exists
  /// anywhere up to the place's state.
  Future<TownFallback?> lookup(
    String text, {
    String? categorySlug,
    int limit = 24,
  }) async {
    final name = text.trim().toLowerCase();
    if (name.length < 3) return null;
    try {
      final rows = await _client
          .from('location_nodes')
          .select('id, name, level, parent_id')
          .eq('normalized_name', name)
          .limit(10);
      final nodes = rows.whereType<Map<String, dynamic>>().where(
        (r) => _levelPriority.contains(r['level']),
      ).toList()
        ..sort(
          (a, b) => _levelPriority
              .indexOf(a['level'] as String)
              .compareTo(_levelPriority.indexOf(b['level'] as String)),
        );
      if (nodes.isEmpty) return null;
      final town = nodes.first;
      final townName = town['name']?.toString() ?? text.trim();

      Map<String, dynamic>? scope = town;
      for (var hop = 0; hop < 4 && scope != null; hop++) {
        final level = scope['level']?.toString() ?? '';
        if (!_levelPriority.contains(level)) break;
        final venues = await _venuesUnder(
          scope['id'] as String,
          categorySlug: categorySlug,
          limit: limit,
        );
        if (venues.isNotEmpty) {
          return TownFallback(
            townName: townName,
            scopeName: scope['name']?.toString() ?? townName,
            scopeLevel: level,
            venues: venues,
          );
        }
        final parentId = scope['parent_id'] as String?;
        if (parentId == null) break;
        scope = await _client
            .from('location_nodes')
            .select('id, name, level, parent_id')
            .eq('id', parentId)
            .maybeSingle();
      }
      return null;
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<Venue>> _venuesUnder(
    String nodeId, {
    String? categorySlug,
    required int limit,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_location_descendants',
      params: {'p_location_id': nodeId},
    );
    final ids = rows
        .map((r) => r is Map ? r['id']?.toString() : r?.toString())
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];
    final hasCategory = categorySlug != null && categorySlug.isNotEmpty;
    var builder = _client
        .from('venues')
        .select(hasCategory ? _venueSelectWithCategory : _venueSelect)
        .eq('is_active', true)
        .inFilter('location_node_id', ids);
    if (hasCategory) {
      builder = builder.eq('venue_categories.slug', categorySlug);
    }
    final venues = await builder
        .order('rating_count', ascending: false)
        .limit(limit);
    return venues
        .whereType<Map<String, dynamic>>()
        .map(Venue.fromJson)
        .toList();
  }
}
