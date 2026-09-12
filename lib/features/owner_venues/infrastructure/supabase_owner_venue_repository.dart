import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../booking/domain/booking.dart';
import '../../venues/domain/venue.dart';
import '../domain/owner_venue_repository.dart';

/// Supabase implementation of [OwnerVenueRepository].
///
/// The deployed schema scopes venues through `organizations.org_id`; there is
/// no `venues.owner_id` column. All operations use the current user's
/// organization and remain subject to Supabase RLS.
class SupabaseOwnerVenueRepository implements OwnerVenueRepository {
  SupabaseOwnerVenueRepository(this._client);

  final SupabaseClient _client;

  static const String _venueSelect = '''
    *,
    venue_categories (id, slug, name, icon, metadata),
    venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order),
    venue_facilities (facility, is_available)
  ''';

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  Future<List<Venue>> myVenues() async {
    try {
      final orgId = await _ownerOrganizationId();
      final rows = await _client
          .from('venues')
          .select(_venueSelect)
          .eq('org_id', orgId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Venue.fromJson)
          .toList();
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<Venue> createVenue({
    required String name,
    required String categoryId,
    required String description,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
    required int capacity,
    required double pricingBaseAmount,
    String? address,
    String? pincode,
    List<VenueImage>? images,
    List<String>? facilities,
    String? videoUrl,
    String? tour3dUrl,
  }) async {
    try {
      final orgId = await _ownerOrganizationId();
      final categoryUuid = await _resolveCategoryId(categoryId);
      final trimmedName = name.trim();
      final payload = <String, dynamic>{
        'org_id': orgId,
        'name': trimmedName,
        'slug': _slugFor(trimmedName),
        'description': description.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'capacity': capacity,
        'pricing_base_amount': pricingBaseAmount,
        'address_line1': _nullableText(address),
        'postal_code': _nullableText(pincode),
        'country': 'IN',
        'is_active': true,
        'is_verified': false,
        if (categoryUuid != null) 'category_id': categoryUuid,
      };

      final inserted =
          await _client.from('venues').insert(payload).select('id').single();
      final venueId = inserted['id'] as String;
      await _syncMedia(
        venueId: venueId,
        venueName: trimmedName,
        images: images,
        facilities: facilities,
        videoUrl: videoUrl,
        tour3dUrl: tour3dUrl,
      );
      return _loadVenue(venueId, orgId);
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<Venue> updateVenue({
    required String venueId,
    String? name,
    String? categoryId,
    String? description,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    int? capacity,
    double? pricingBaseAmount,
    bool? isActive,
    String? address,
    String? pincode,
    List<VenueImage>? images,
    List<String>? facilities,
    String? videoUrl,
    String? tour3dUrl,
  }) async {
    try {
      final orgId = await _ownerOrganizationId();
      final update = <String, dynamic>{};
      if (name != null) {
        update['name'] = name.trim();
        update['slug'] = _slugFor(name);
      }
      if (categoryId != null) {
        final categoryUuid = await _resolveCategoryId(categoryId);
        if (categoryId.trim().isNotEmpty && categoryUuid == null) {
          throw const app_errors.NotFoundException('Venue category not found.');
        }
        update['category_id'] = categoryUuid;
      }
      if (description != null) update['description'] = description.trim();
      if (city != null) update['city'] = city.trim();
      if (state != null) update['state'] = state.trim();
      if (latitude != null) update['latitude'] = latitude;
      if (longitude != null) update['longitude'] = longitude;
      if (capacity != null) update['capacity'] = capacity;
      if (pricingBaseAmount != null) {
        update['pricing_base_amount'] = pricingBaseAmount;
      }
      if (isActive != null) update['is_active'] = isActive;
      if (address != null) update['address_line1'] = _nullableText(address);
      if (pincode != null) update['postal_code'] = _nullableText(pincode);

      if (update.isNotEmpty) {
        final changed = await _client
            .from('venues')
            .update(update)
            .eq('id', venueId)
            .eq('org_id', orgId)
            .isFilter('deleted_at', null)
            .select('id')
            .maybeSingle();
        if (changed == null) {
          throw const app_errors.NotFoundException(
            'Venue not found or not owned by this account.',
          );
        }
      } else {
        final existing = await _client
            .from('venues')
            .select('id')
            .eq('id', venueId)
            .eq('org_id', orgId)
            .isFilter('deleted_at', null)
            .maybeSingle();
        if (existing == null) {
          throw const app_errors.NotFoundException(
            'Venue not found or not owned by this account.',
          );
        }
      }

      if (images != null ||
          facilities != null ||
          _hasText(videoUrl) ||
          _hasText(tour3dUrl)) {
        await _syncMedia(
          venueId: venueId,
          venueName: name,
          images: images,
          facilities: facilities,
          videoUrl: videoUrl,
          tour3dUrl: tour3dUrl,
        );
      }
      return _loadVenue(venueId, orgId);
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    try {
      final orgId = await _ownerOrganizationId();
      final deleted = await _client
          .from('venues')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'is_active': false,
          })
          .eq('id', venueId)
          .eq('org_id', orgId)
          .isFilter('deleted_at', null)
          .select('id')
          .maybeSingle();
      if (deleted == null) {
        throw const app_errors.NotFoundException(
          'Venue not found or not owned by this account.',
        );
      }
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  Future<String> _ownerOrganizationId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const app_errors.AuthException(
          'Sign in as an owner to manage venues.');
    }

    final organization = await _client
        .from('organizations')
        .select('id')
        .eq('owner_user_id', user.id)
        .isFilter('deleted_at', null)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();
    final organizationId = organization?['id'] as String?;
    if (organizationId == null || organizationId.isEmpty) {
      throw const app_errors.AuthException(
        'No active owner organization is linked to this account.',
      );
    }
    return organizationId;
  }

  Future<String?> _resolveCategoryId(String value) async {
    final category = value.trim();
    if (category.isEmpty) return null;
    if (_uuid.hasMatch(category)) return category;

    final row = await _client
        .from('venue_categories')
        .select('id')
        .eq('slug', category)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<Venue> _loadVenue(String venueId, String organizationId) async {
    final row = await _client
        .from('venues')
        .select(_venueSelect)
        .eq('id', venueId)
        .eq('org_id', organizationId)
        .maybeSingle();
    if (row == null) {
      throw const app_errors.NotFoundException('Venue could not be loaded.');
    }
    return Venue.fromJson(row);
  }

  Future<void> _syncMedia({
    required String venueId,
    required String? venueName,
    List<VenueImage>? images,
    List<String>? facilities,
    String? videoUrl,
    String? tour3dUrl,
  }) async {
    if (images != null || _hasText(videoUrl) || _hasText(tour3dUrl)) {
      await _client.from('venue_images').delete().eq('venue_id', venueId);
      final rows = <Map<String, dynamic>>[];
      for (final image in images ?? const <VenueImage>[]) {
        if (image.url.trim().isEmpty) continue;
        rows.add({
          'venue_id': venueId,
          'url': image.url.trim(),
          'thumbnail_url': image.thumbnailUrl,
          'alt_text': image.altText ?? venueName,
          'is_cover': image.isCover,
          'sort_order': image.sortOrder,
        });
      }
      if (_hasText(videoUrl)) {
        rows.add({
          'venue_id': venueId,
          'url': videoUrl!.trim(),
          'alt_text': '$venueName video',
          'media_kind': 'video',
          'sort_order': rows.length,
        });
      }
      if (_hasText(tour3dUrl)) {
        rows.add({
          'venue_id': venueId,
          'url': tour3dUrl!.trim(),
          'alt_text': '$venueName 3D tour',
          'media_kind': 'model_3d',
          'sort_order': rows.length,
        });
      }
      if (rows.isNotEmpty) await _client.from('venue_images').insert(rows);
    }

    if (facilities != null) {
      await _client.from('venue_facilities').delete().eq('venue_id', venueId);
      final rows = facilities
          .map((facility) => facility.trim())
          .where((facility) => facility.isNotEmpty)
          .map((facility) => {
                'venue_id': venueId,
                'facility': facility,
                'is_available': true,
              })
          .toList();
      if (rows.isNotEmpty) {
        await _client.from('venue_facilities').insert(rows);
      }
    }
  }

  static String _slugFor(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'venue' : slug;
  }

  static String? _nullableText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;

  static const _maxImageBytes = 8 * 1024 * 1024;
  static const _allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  @override
  Future<String> uploadVenueImage({
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) async {
    try {
      if (bytes.isEmpty) {
        throw const app_errors.ValidationException('The selected image is empty.');
      }
      if (bytes.length > _maxImageBytes) {
        throw const app_errors.ValidationException(
          'Image is too large. Use a file under 8 MB.',
        );
      }
      final extension = _extensionFor(fileName, contentType);
      if (!_allowedImageExtensions.contains(extension)) {
        throw const app_errors.ValidationException(
          'Unsupported image type. Use JPG, PNG, WEBP, or HEIC.',
        );
      }
      final orgId = await _ownerOrganizationId();
      final objectPath =
          '$orgId/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await _client.storage.from('venue-images').uploadBinary(
            objectPath,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: contentType ?? 'image/$extension',
              upsert: false,
            ),
          );
      return _client.storage.from('venue-images').getPublicUrl(objectPath);
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<void> deleteStoredImage(String pathOrUrl) async {
    try {
      final path = _storagePathFrom(pathOrUrl);
      if (path == null) return;
      await _client.storage.from('venue-images').remove([path]);
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<List<TimeSlot>> listTimeSlots(String venueId) async {
    try {
      final rows = await _client
          .from('time_slots')
          .select('*')
          .eq('venue_id', venueId)
          .order('start_time');
      return rows.whereType<Map<String, dynamic>>().map(TimeSlot.fromJson).toList();
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<void> replaceTimeSlots(String venueId, List<TimeSlotDraft> slots) async {
    try {
      await _assertOwnedVenue(venueId);
      _assertValidSlots(slots);
      final existing = await listTimeSlots(venueId);
      final incomingIds = slots
          .map((slot) => slot.id)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      for (final current in existing) {
        if (!incomingIds.contains(current.id)) {
          await _client.from('time_slots').update({'is_active': false}).eq(
            'id',
            current.id,
          );
        }
      }

      for (final slot in slots) {
        final payload = {
          'venue_id': venueId,
          'label': slot.label.trim(),
          'start_time': slot.startTime,
          'end_time': slot.endTime,
          'price_amount': slot.priceAmount,
          'is_active': slot.isActive,
        };
        if (slot.id != null &&
            slot.id!.isNotEmpty &&
            existing.any((item) => item.id == slot.id)) {
          await _client.from('time_slots').update(payload).eq('id', slot.id!);
        } else {
          await _client.from('time_slots').insert(payload);
        }
      }
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<List<VenueBlockedDate>> listBlockedDates(String venueId) async {
    try {
      final rows = await _client
          .from('venue_blocked_dates')
          .select('*')
          .eq('venue_id', venueId)
          .order('blocked_date');
      return rows.whereType<Map<String, dynamic>>().map((row) {
        return VenueBlockedDate(
          id: row['id'] as String?,
          date: DateTime.tryParse(row['blocked_date'] as String? ?? '') ??
              DateTime.now(),
          reason: row['reason'] as String?,
        );
      }).toList();
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }

  @override
  Future<void> replaceBlockedDates(
    String venueId,
    List<VenueBlockedDate> dates,
  ) async {
    try {
      await _assertOwnedVenue(venueId);
      await _client.from('venue_blocked_dates').delete().eq('venue_id', venueId);
      if (dates.isEmpty) return;
      final rows = dates.map((item) {
        final date = item.date.toUtc();
        final iso =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        return {
          'venue_id': venueId,
          'blocked_date': iso,
          if (item.reason != null && item.reason!.trim().isNotEmpty)
            'reason': item.reason!.trim(),
        };
      }).toList();
      await _client.from('venue_blocked_dates').insert(rows);
    } catch (error) {
      if (error is app_errors.AppException) rethrow;
      throw app_errors.mapError(error);
    }
  }

  Future<void> _assertOwnedVenue(String venueId) async {
    final orgId = await _ownerOrganizationId();
    final existing = await _client
        .from('venues')
        .select('id')
        .eq('id', venueId)
        .eq('org_id', orgId)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (existing == null) {
      throw const app_errors.NotFoundException(
        'Venue not found or not owned by this account.',
      );
    }
  }

  static void _assertValidSlots(List<TimeSlotDraft> slots) {
    final message = validateTimeSlotDrafts(slots);
    if (message != null) {
      throw app_errors.ValidationException(message);
    }
  }

  static String _extensionFor(String fileName, String? contentType) {
    final fromName = fileName.split('.').last.toLowerCase();
    if (_allowedImageExtensions.contains(fromName)) return fromName;
    final type = (contentType ?? '').toLowerCase();
    if (type.contains('png')) return 'png';
    if (type.contains('webp')) return 'webp';
    if (type.contains('heic')) return 'heic';
    if (type.contains('heif')) return 'heif';
    return 'jpg';
  }

  static String? _storagePathFrom(String pathOrUrl) {
    const marker = '/venue-images/';
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return null;
    final index = trimmed.indexOf(marker);
    if (index >= 0) {
      return Uri.decodeComponent(trimmed.substring(index + marker.length));
    }
    if (!trimmed.startsWith('http')) return trimmed;
    return null;
  }
}
