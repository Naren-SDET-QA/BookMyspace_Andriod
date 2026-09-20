import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart'
    show BusinessException, NotFoundException, mapError;
import '../../../core/firebase/error_logger.dart';
import '../../../core/network/retry.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';

/// Supabase-backed [VenueRepository].
///
/// Queries are RLS-safe: venue data is publicly readable, favourites are
/// scoped to the authenticated user.
class SupabaseVenueRepository implements VenueRepository {
  SupabaseVenueRepository(this._client);

  final SupabaseClient _client;

  static const String _venueSelect = '''
    *,
    venue_categories (id, slug, name, icon, metadata, parent_section, is_active, description, image_url),
    venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order),
    venue_facilities (facility, is_available)
  ''';

  @override
  Future<List<VenueCategory>> categories({bool activeOnly = false}) async {
    try {
      var query = _client.from('venue_categories').select('*');
      if (activeOnly) query = query.eq('is_active', true);
      final rows = await query.order('display_order').order('name');
      return rows.map(VenueCategory.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueCategory> getCategory(String id) async {
    try {
      final row = await _client
          .from('venue_categories')
          .select('*')
          .eq('id', id)
          .single();
      if (row == null) {
        throw const NotFoundException('Category not found.');
      }
      return VenueCategory.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueCategory> addCategory({
    required String name,
    required String slug,
    String? icon,
    String? parentSection,
    bool isActive = true,
    ListingTemplateConfig? listingConfig = null,
  }) async {
    try {
      _validateNameAndSlug(name, slug);
      final insertData = {
        'name': name,
        'slug': slug.trim().toLowerCase(),
        'icon': icon ?? '🏷️',
        'is_active': isActive,
        'parent_section': parentSection ?? 'general',
        'display_order': await _nextCategoryOrder(),
        'metadata': {
          'active': isActive,
          'parent_section': parentSection ?? 'general',
        },
      };
      if (listingConfig != null) {
        insertData['metadata']['listing'] = listingConfig.toJson();
      }
      final row = await _client
          .from('venue_categories')
          .insert(insertData)
          .select()
          .single();
      final created = VenueCategory.fromJson(row);
      return created;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueCategory> updateCategory(VenueCategory category) async {
    try {
      _validateNameAndSlug(category.name, category.slug);
      final existing = await _client
          .from('venue_categories')
          .select('metadata')
          .eq('id', category.id)
          .single();
      final metadata = existing['metadata'] is Map
          ? Map<String, dynamic>.from(existing['metadata'] as Map)
          : <String, dynamic>{};
      metadata['active'] = category.isActive;
      metadata['parent_section'] = category.parentSection ?? 'general';
      if (category.listingConfig != null) {
        metadata['listing'] = category.listingConfig!.toJson();
      }
      final row = await _client
          .from('venue_categories')
          .update({
            'name': category.name,
            'slug': category.slug.trim().toLowerCase(),
            'icon': category.icon,
            'is_active': category.isActive,
            'parent_section': category.parentSection ?? 'general',
            'description': category.description,
            'image_url': category.imageUrl.isEmpty ? null : category.imageUrl,
            'image_path':
                category.imagePath.isEmpty ? null : category.imagePath,
            'display_order': category.displayOrder,
            'supported_languages': category.supportedLanguages,
            'name_i18n': category.nameTranslations,
            'description_i18n': category.descriptionTranslations,
            'metadata': metadata,
          })
          .eq('id', category.id)
          .select()
          .single();
      final updated = VenueCategory.fromJson(row);
      return updated;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> setCategoryActive(String categoryId, bool isActive) async {
    try {
      final current = await _client
          .from('venue_categories')
          .select('metadata')
          .eq('id', categoryId)
          .single();
      final metadata = current['metadata'] is Map
          ? Map<String, dynamic>.from(current['metadata'] as Map)
          : <String, dynamic>{};
      metadata['active'] = isActive;
      await _client.from('venue_categories').update({
        'is_active': isActive,
        'metadata': metadata,
      }).eq('id', categoryId);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Stream<List<VenueCategory>> categoryStream({bool activeOnly = false}) {
    final filtered = activeOnly
        ? _client
            .from('venue_categories')
            .stream(primaryKey: ['id']).eq('is_active', true)
        : _client.from('venue_categories').stream(primaryKey: ['id']);
    return filtered
        .order('display_order', ascending: true)
        .order('name', ascending: true)
        .map(
          (rows) => rows.map(VenueCategory.fromJson).toList(growable: false),
        );
  }

  @override
  Future<List<VenueSubsection>> subsections(
    String categoryId, {
    bool activeOnly = false,
  }) async {
    try {
      var query = _client
          .from('venue_subsections')
          .select('*')
          .eq('category_id', categoryId);
      if (activeOnly) query = query.eq('is_active', true);
      final rows = await query.order('display_order').order('name');
      return rows.map(VenueSubsection.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Stream<List<VenueSubsection>> subsectionStream(
    String categoryId, {
    bool activeOnly = false,
  }) {
    var filtered = _client
        .from('venue_subsections')
        .stream(primaryKey: ['id']).eq('category_id', categoryId);
    if (activeOnly) filtered = filtered.eq('is_active', true);
    return filtered
        .order('display_order', ascending: true)
        .order('name', ascending: true)
        .map(
          (rows) => rows.map(VenueSubsection.fromJson).toList(growable: false),
        );
  }

  @override
  Stream<List<VenueSubsection>> subsectionCatalogStream({
    bool activeOnly = true,
  }) {
    var filtered = _client.from('venue_subsections').stream(primaryKey: ['id']);
    if (activeOnly) filtered = filtered.eq('is_active', true);
    return filtered
        .order('display_order', ascending: true)
        .order('name', ascending: true)
        .map(
          (rows) => rows.map(VenueSubsection.fromJson).toList(growable: false),
        );
  }

  @override
  Future<VenueSubsection> addSubsection({
    required String categoryId,
    required String name,
    required String slug,
    String? icon,
    String description = '',
    String? imageUrl,
    String? imagePath,
    bool isActive = true,
    int displayOrder = 0,
    List<String> supportedLanguages = const ['en'],
    Map<String, String> nameTranslations = const {},
    Map<String, String> descriptionTranslations = const {},
  }) async {
    try {
      _validateNameAndSlug(name, slug);
      final row = await _client
          .from('venue_subsections')
          .insert({
            'category_id': categoryId,
            'name': name.trim(),
            'slug': slug.trim().toLowerCase(),
            'icon': icon,
            'description': description.trim(),
            'image_url': imageUrl,
            'image_path': imagePath,
            'is_active': isActive,
            'display_order': displayOrder == 0
                ? await _nextSubsectionOrder(categoryId)
                : displayOrder,
            'supported_languages': supportedLanguages,
            'name_i18n': nameTranslations,
            'description_i18n': descriptionTranslations,
          })
          .select()
          .single();
      return VenueSubsection.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueSubsection> updateSubsection(VenueSubsection subsection) async {
    try {
      _validateNameAndSlug(subsection.name, subsection.slug);
      final row = await _client
          .from('venue_subsections')
          .update({
            'category_id': subsection.categoryId,
            'name': subsection.name.trim(),
            'slug': subsection.slug.trim().toLowerCase(),
            'icon': subsection.icon,
            'description': subsection.description,
            'image_url':
                subsection.imageUrl.isEmpty ? null : subsection.imageUrl,
            'image_path':
                subsection.imagePath.isEmpty ? null : subsection.imagePath,
            'is_active': subsection.isActive,
            'display_order': subsection.displayOrder,
            'supported_languages': subsection.supportedLanguages,
            'name_i18n': subsection.nameTranslations,
            'description_i18n': subsection.descriptionTranslations,
          })
          .eq('id', subsection.id)
          .select()
          .single();
      return VenueSubsection.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      final categoryRow = await _client
          .from('venue_categories')
          .select('image_path')
          .eq('id', categoryId)
          .maybeSingle();
      final subsectionRows = await _client
          .from('venue_subsections')
          .select('image_path')
          .eq('category_id', categoryId);
      await _client.from('venue_categories').delete().eq('id', categoryId);
      final paths = <String>[
        if (categoryRow?['image_path'] is String)
          categoryRow!['image_path'] as String,
        ...subsectionRows.map((row) => row['image_path']).whereType<String>(),
      ].where((path) => path.isNotEmpty).toList();
      if (paths.isNotEmpty) {
        await _client.storage.from('category-media').remove(paths);
      }
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteSubsection(String subsectionId) async {
    try {
      final row = await _client
          .from('venue_subsections')
          .select('image_path')
          .eq('id', subsectionId)
          .maybeSingle();
      await _client.from('venue_subsections').delete().eq('id', subsectionId);
      final path = row?['image_path'];
      if (path is String && path.isNotEmpty) {
        await _client.storage.from('category-media').remove([path]);
      }
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> reorderCategories(List<String> categoryIds) async {
    try {
      await _client.rpc(
        'reorder_category_catalog',
        params: {'p_category_ids': categoryIds},
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> reorderSubsections(
    String categoryId,
    List<String> subsectionIds,
  ) async {
    try {
      await _client.rpc(
        'reorder_category_subsections',
        params: {
          'p_category_id': categoryId,
          'p_subsection_ids': subsectionIds,
        },
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueCategory> uploadCategoryImage({
    required VenueCategory category,
    required List<int> bytes,
    required String extension,
  }) async {
    try {
      final path = _mediaPath('categories', category.id, extension);
      await _client.storage.from('category-media').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              upsert: false,
            ),
          );
      final updated = await updateCategory(
        category.copyWith(
          imageUrl: _client.storage.from('category-media').getPublicUrl(path),
          imagePath: path,
        ),
      );
      await _removeOldMedia(category.imagePath, except: path);
      return updated;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> removeCategoryImage(VenueCategory category) async {
    try {
      await _removeOldMedia(category.imagePath);
      await updateCategory(
          category.copyWith(clearImage: true, clearImagePath: true));
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueSubsection> uploadSubsectionImage({
    required VenueSubsection subsection,
    required List<int> bytes,
    required String extension,
  }) async {
    try {
      final path = _mediaPath('subsections', subsection.id, extension);
      await _client.storage.from('category-media').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              upsert: false,
            ),
          );
      final updated = await updateSubsection(
        subsection.copyWith(
          imageUrl: _client.storage.from('category-media').getPublicUrl(path),
          imagePath: path,
        ),
      );
      await _removeOldMedia(subsection.imagePath, except: path);
      return updated;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> removeSubsectionImage(VenueSubsection subsection) async {
    try {
      await _removeOldMedia(subsection.imagePath);
      await updateSubsection(
          subsection.copyWith(clearImage: true, clearImagePath: true));
    } catch (e) {
      throw mapError(e);
    }
  }

  void _validateNameAndSlug(String name, String slug) {
    if (name.trim().isEmpty || name.trim().length > 120) {
      throw const BusinessException(
          'Name must contain between 1 and 120 characters.');
    }
    if (!RegExp(r'^[a-z0-9]+(?:[-_][a-z0-9]+)*$')
        .hasMatch(slug.trim().toLowerCase())) {
      throw const BusinessException(
          'SEO slug may contain lowercase letters, numbers, hyphens, and underscores.');
    }
  }

  Future<int> _nextCategoryOrder() async {
    final rows = await _client
        .from('venue_categories')
        .select('display_order')
        .order('display_order', ascending: false)
        .limit(1);
    return rows.isEmpty
        ? 0
        : ((rows.first['display_order'] as num?)?.toInt() ?? -1) + 1;
  }

  Future<int> _nextSubsectionOrder(String categoryId) async {
    final rows = await _client
        .from('venue_subsections')
        .select('display_order')
        .eq('category_id', categoryId)
        .order('display_order', ascending: false)
        .limit(1);
    return rows.isEmpty
        ? 0
        : ((rows.first['display_order'] as num?)?.toInt() ?? -1) + 1;
  }

  String _mediaPath(String folder, String entityId, String extension) {
    final safeExtension =
        extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$folder/$entityId/${DateTime.now().microsecondsSinceEpoch}.${safeExtension.isEmpty ? 'jpg' : safeExtension}';
  }

  String _contentType(String extension) {
    return switch (extension.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  Future<void> _removeOldMedia(String path, {String? except}) async {
    if (path.isEmpty || path == except) return;
    await _client.storage.from('category-media').remove([path]);
  }

  @override
  Future<List<String>> listedCities() async {
    try {
      final rows = await _client
          .from('venues')
          .select('city')
          .eq('is_active', true)
          .not('city', 'is', null)
          .order('city')
          .limit(200);
      final cities = <String>{};
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final city = (row['city'] as String? ?? '').trim();
        if (city.isNotEmpty) cities.add(city);
      }
      final list = cities.toList()..sort();
      return list;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Venue>> popularVenues({int limit = 10}) async {
    try {
      final rows = await _client
          .from('venues')
          .select(_venueSelect)
          .eq('is_active', true)
          .order('rating_count', ascending: false)
          .order('avg_rating', ascending: false)
          .limit(limit);
      return rows.map(Venue.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  }) async {
    try {
      final data = await _client.rpc<List<dynamic>>(
        'nearby_venues',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'radius_km': maxDistanceKm,
          'max_rows': limit,
        },
      );
      return data.whereType<Map<String, dynamic>>().map(_fromRow).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Venue>> search(VenueSearchQuery query) async {
    try {
      return await withReadRetry(() => _searchOnce(query));
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<List<Venue>> _searchOnce(VenueSearchQuery query) async {
    try {
      if (query.hasCoordinates) {
        final nearby = await nearbyVenues(
          latitude: query.latitude!,
          longitude: query.longitude!,
          maxDistanceKm: (query.radiusKm ?? 10).toDouble(),
          limit: query.limit.clamp(1, 50),
        );
        return nearby.where((venue) {
          if (query.categorySlug != null &&
              query.categorySlug!.trim().isNotEmpty &&
              venue.category?.slug != query.categorySlug) {
            return false;
          }
          if (query.minPrice != null &&
              venue.pricingBaseAmount < query.minPrice!) {
            return false;
          }
          if (query.maxPrice != null &&
              venue.pricingBaseAmount > query.maxPrice!) {
            return false;
          }
          if (query.query.trim().isNotEmpty) {
            final haystack = '${venue.name} ${venue.city} ${venue.description}'
                .toLowerCase();
            if (!haystack.contains(query.query.trim().toLowerCase())) {
              return false;
            }
          }
          if (query.facility != null && query.facility!.trim().isNotEmpty) {
            final needle = query.facility!.trim().toLowerCase();
            if (!venue.facilities.any(
              (item) =>
                  item.isAvailable && item.facility.toLowerCase() == needle,
            )) {
              return false;
            }
          }
          return true;
        }).toList();
      }

      // Phase 9XM-1 perf fix: previously this did a separate awaited
      // round trip to resolve venue_categories.id from the slug, THEN
      // filtered venues by that id -- two sequential network calls for
      // every category-filtered search. PostgREST/Supabase supports
      // filtering directly on an embedded (!inner-joined) resource's own
      // columns in the same request, so the slug filter is applied
      // in-line against the joined venue_categories relationship below,
      // collapsing this to a single query. All other filters, ordering,
      // pagination, and the response shape (Venue.fromJson mapping) are
      // unchanged.
      //
      // NOTE (documented, deliberate, narrow behavior difference): the
      // previous code silently skipped the category filter entirely if
      // the slug matched no row in venue_categories (categoryId stayed
      // null), returning all active venues that have *any* category.
      // With the single-query filter below, a category slug that matches
      // no row now correctly returns zero results instead of silently
      // ignoring the filter. This only affects the edge case of a
      // nonexistent/stale category slug, which the UI does not produce
      // today (slugs always come from the categories list itself).

      // Use inner join syntax on venue_categories when filtering by category to avoid PostgREST 42803 grouping errors
      final selectClause = (query.categorySlug != null)
          ? '''
            *,
            venue_categories!inner (id, slug, name, icon, metadata, parent_section, is_active, description, image_url),
            venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order),
            venue_facilities (facility, is_available)
          '''
          : _venueSelect;

      var builder =
          _client.from('venues').select(selectClause).eq('is_active', true);

      if (query.query.trim().isNotEmpty) {
        builder = builder.textSearch('search_document', query.query.trim());
      }
      if (query.categorySlug != null) {
        builder = builder.eq('venue_categories.slug', query.categorySlug!);
      }
      if (query.pincode != null && query.pincode!.trim().isNotEmpty) {
        final pin = query.pincode!.trim();
        final city = query.city?.trim();
        if (city != null && city.isNotEmpty) {
          builder = builder.or(
            'postal_code.eq.$pin,city.ilike.%$city%',
          );
        } else {
          builder = builder.eq('postal_code', pin);
        }
      } else if (query.city != null && query.city!.trim().isNotEmpty) {
        builder = builder.ilike('city', '%${query.city!.trim()}%');
      }
      if (query.minPrice != null) {
        builder = builder.gte('pricing_base_amount', query.minPrice!);
      }
      if (query.maxPrice != null) {
        builder = builder.lte('pricing_base_amount', query.maxPrice!);
      }

      final (orderColumn, ascending) = switch (query.sortBy) {
        VenueSortBy.priceAsc => ('pricing_base_amount', true),
        VenueSortBy.priceDesc => ('pricing_base_amount', false),
        VenueSortBy.rating => ('avg_rating', false),
        // Distance ordering is handled by the RPC path; fall back to
        // popularity for the REST query.
        VenueSortBy.distance || VenueSortBy.relevance => (
            'rating_count',
            false
          ),
      };

      // Log exact SQL executed for function hall / category searches.
      // Phase 9XL perf fix: this diagnostic string-build + log call ran on
      // EVERY category-filtered search request in production, even though
      // nothing consumes it outside local debugging. Gating it behind
      // kDebugMode removes that per-request CPU/string-alloc/log overhead
      // in release builds without changing search results or behavior.
      if (kDebugMode && query.categorySlug != null) {
        // Phase 9XM-1: updated to reflect the single-query slug filter;
        // `categoryId` no longer exists (no separate lookup is made).
        // Diagnostic-only -- gated by kDebugMode since Phase 9XL, never
        // affects query results.
        final executedSql = "SELECT $selectClause FROM venues"
            " INNER JOIN venue_categories ON venue_categories.id = venues.category_id"
            " WHERE venues.is_active = true"
            " AND venue_categories.slug = '${query.categorySlug}'"
            "${query.query.trim().isNotEmpty ? " AND search_document @@ to_tsquery('${query.query.trim()}')" : ""}"
            "${query.city != null && query.city!.trim().isNotEmpty ? " AND city ILIKE '%${query.city!.trim()}%'" : ""}"
            " ORDER BY $orderColumn ${ascending ? 'ASC' : 'DESC'} LIMIT ${query.limit.clamp(1, 50)};";

        ErrorLogger.logMessage(
          'Executing PostgREST Category Search SQL (Phase 9XM-1 single-query slug filter) [slug=${query.categorySlug}]: $executedSql',
          context: 'SupabaseVenueRepository.search',
        );
      }

      final pageSize = query.limit.clamp(1, 50);
      final start = query.offset < 0 ? 0 : query.offset;
      final rows = await builder
          .order(orderColumn, ascending: ascending)
          .range(start, start + pageSize - 1);
      var results =
          rows.whereType<Map<String, dynamic>>().map(Venue.fromJson).toList();
      if (query.facility != null && query.facility!.trim().isNotEmpty) {
        final needle = query.facility!.trim().toLowerCase();
        results = results
            .where(
              (venue) => venue.facilities.any(
                (item) =>
                    item.isAvailable && item.facility.toLowerCase() == needle,
              ),
            )
            .toList();
      }
      return results;
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Venue> venueById(String id) async {
    try {
      final row = await _client
          .from('venues')
          .select(
            '$_venueSelect, venue_facilities (facility, is_available), '
            'venue_operating_hours (day_of_week, opens_at, closes_at, is_closed)',
          )
          .eq('id', id)
          .maybeSingle();
      if (row == null) {
        throw const NotFoundException('Venue not found', code: 'not_found');
      }
      return Venue.fromJson(row);
    } catch (e) {
      if (e is NotFoundException) rethrow;
      throw mapError(e);
    }
  }

  @override
  Future<List<String>> favoriteIds() async {
    try {
      final rows = await _client.from('favorites').select('venue_id');
      return rows.map((r) => r['venue_id'] as String).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Venue>> favorites() async {
    try {
      final ids = await favoriteIds();
      if (ids.isEmpty) return const [];
      final rows = await _client
          .from('venues')
          .select(_venueSelect)
          .inFilter('id', ids)
          .eq('is_active', true);
      return rows.map(Venue.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> addFavorite(String venueId) async {
    try {
      await _client.from('favorites').insert({'venue_id': venueId});
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> removeFavorite(String venueId) async {
    try {
      await _client.from('favorites').delete().eq('venue_id', venueId);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Maps an RPC row (which lacks embedded collections) to a [Venue].
  Venue _fromRow(Map<String, dynamic> row) => Venue.fromJson(row);
}
