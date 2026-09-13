import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/venue_section.dart';
import '../domain/venue_section_repository.dart';

/// Supabase-backed [VenueSectionRepository].
///
/// Every draft mutation relies on the deployed RLS policies scoped to
/// `owns_venue()` -- this class never decides who may edit what, it only
/// issues the request and lets the server accept or refuse it. Customer
/// content is read exclusively through the `list_published_venue_sections`
/// RPC, never by selecting the draft table directly.
class SupabaseVenueSectionRepository implements VenueSectionRepository {
  SupabaseVenueSectionRepository(this._client);

  final SupabaseClient _client;

  static const String _sectionSelect = '''
    *,
    venue_section_types (
      id, key, name, description, icon, allows_multiple,
      available_subsections, editable_fields, is_active, display_order
    )
  ''';

  @override
  Future<List<VenueSectionType>> sectionTypes() async {
    try {
      final rows = await _client
          .from('venue_section_types')
          .select()
          .eq('is_active', true)
          .order('display_order');
      return rows.map(VenueSectionType.fromJson).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<VenueSection>> ownerVenueSections(String venueId) async {
    try {
      final rows = await _client
          .from('venue_sections')
          .select(_sectionSelect)
          .eq('venue_id', venueId)
          .order('display_order');
      return rows.map(VenueSection.fromJson).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Stream<List<VenueSection>> ownerVenueSectionsStream(String venueId) {
    return _client
        .from('venue_sections')
        .stream(primaryKey: ['id'])
        .eq('venue_id', venueId)
        .order('display_order')
        .asyncMap((rows) async {
      // Realtime payloads do not include embedded relations, so re-fetch
      // the type catalog once per emission and join it client-side.
      final types = await sectionTypes();
      final typesById = {for (final t in types) t.id: t};
      return rows.map((row) {
        final typeId = row['section_type_id'] as String?;
        final merged = Map<String, dynamic>.from(row);
        final type = typesById[typeId];
        if (type != null) {
          merged['venue_section_types'] = {
            'id': type.id,
            'key': type.key,
            'name': type.name,
            'description': type.description,
            'icon': type.icon,
            'allows_multiple': type.allowsMultiple,
            'available_subsections': type.availableSubsections
                .map((s) => {'key': s.key, 'label': s.label})
                .toList(),
            'editable_fields': type.editableFields,
            'is_active': type.isActive,
            'display_order': type.displayOrder,
          };
        }
        return VenueSection.fromJson(merged);
      }).toList();
    });
  }

  @override
  Future<VenueSection> addSection({
    required String venueId,
    required VenueSectionType type,
  }) async {
    try {
      final row = await _client
          .from('venue_sections')
          .insert({
            'venue_id': venueId,
            'section_type_id': type.id,
            'is_enabled': true,
            'title': type.name,
          })
          .select(_sectionSelect)
          .single();
      return VenueSection.fromJson(row);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<VenueSection> updateSection(VenueSection section) async {
    try {
      final row = await _client
          .from('venue_sections')
          .update({
            'is_enabled': section.isEnabled,
            'title': section.title,
            'title_i18n': section.titleTranslations,
            'content': section.content,
            'content_i18n': section.contentTranslations,
            'image_url': section.imageUrl.isEmpty ? null : section.imageUrl,
            'image_path':
                section.imagePath.isEmpty ? null : section.imagePath,
            'icon': section.icon,
            'display_order': section.displayOrder,
            'visible_subsections': section.visibleSubsections,
            'config': section.config,
          })
          .eq('id', section.id)
          .select(_sectionSelect)
          .single();
      return VenueSection.fromJson(row);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> deleteSection(String sectionId) async {
    try {
      await _client.from('venue_sections').delete().eq('id', sectionId);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> reorderSections(
    String venueId,
    List<String> sectionIds,
  ) async {
    try {
      for (var i = 0; i < sectionIds.length; i++) {
        await _client
            .from('venue_sections')
            .update({'display_order': i})
            .eq('id', sectionIds[i])
            .eq('venue_id', venueId);
      }
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<VenueSection> uploadSectionImage({
    required VenueSection section,
    required List<int> bytes,
    required String extension,
  }) async {
    try {
      final orgId = await _ownerOrganizationIdFor(section.venueId);
      final path =
          '$orgId/sections/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _client.storage.from('venue-images').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              upsert: true,
            ),
          );
      final url = _client.storage.from('venue-images').getPublicUrl(path);
      if (section.imagePath.isNotEmpty) {
        await _removeStoredImage(section.imagePath);
      }
      final row = await _client
          .from('venue_sections')
          .update({'image_url': url, 'image_path': path})
          .eq('id', section.id)
          .select(_sectionSelect)
          .single();
      return VenueSection.fromJson(row);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> removeSectionImage(VenueSection section) async {
    try {
      if (section.imagePath.isNotEmpty) {
        await _removeStoredImage(section.imagePath);
      }
      await _client
          .from('venue_sections')
          .update({'image_url': null, 'image_path': null})
          .eq('id', section.id);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> publish(String venueId) async {
    try {
      final result = await _client.rpc<Map<String, dynamic>>(
        'publish_venue_sections',
        params: {'p_venue_id': venueId},
      );
      if (result['success'] != true) {
        throw app_errors.BusinessException(
          (result['error_code'] as String?) ?? 'Could not publish sections.',
        );
      }
      return result;
    } catch (e) {
      if (e is app_errors.AppException) rethrow;
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<PublishedVenueSection>> publishedSections(
    String venueId,
  ) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'list_published_venue_sections',
        params: {'p_venue_id': venueId},
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PublishedVenueSection.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  Future<void> _removeStoredImage(String path) async {
    try {
      await _client.storage.from('venue-images').remove([path]);
    } catch (_) {
      // Best-effort cleanup; a dangling object is not worth failing the
      // user-visible mutation over.
    }
  }

  Future<String> _ownerOrganizationIdFor(String venueId) async {
    final row = await _client
        .from('venues')
        .select('org_id')
        .eq('id', venueId)
        .single();
    final orgId = row['org_id'] as String?;
    if (orgId == null || orgId.isEmpty) {
      throw const app_errors.NotFoundException('Venue organisation not found.');
    }
    return orgId;
  }

  String _contentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
