import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../courses/domain/course.dart';
import '../../events/domain/event.dart';
import '../../support/domain/support_ticket.dart';
import '../../venues/domain/venue.dart';
import '../domain/admin_directory.dart';
import '../domain/admin_directory_repository.dart';

class SupabaseAdminDirectoryRepository implements AdminDirectoryRepository {
  SupabaseAdminDirectoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminUserRecord>> listUsers({int limit = 100}) async {
    try {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name, email, phone, created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      final roles = await _client
          .from('user_roles')
          .select('user_id, role, revoked_at');
      final rolesByUser = <String, List<String>>{};
      for (final row in roles.whereType<Map<String, dynamic>>()) {
        if (row['revoked_at'] != null) continue;
        final userId = row['user_id'] as String? ?? '';
        final role = row['role'] as String? ?? '';
        if (userId.isEmpty || role.isEmpty) continue;
        rolesByUser.putIfAbsent(userId, () => <String>[]).add(role);
      }
      return profiles
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final id = row['id'] as String? ?? '';
            return AdminUserRecord(
              id: id,
              fullName: row['full_name'] as String? ?? '',
              email: row['email'] as String? ?? '',
              phone: row['phone'] as String? ?? '',
              roles: rolesByUser[id] ?? const [],
              createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
            );
          })
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<AdminOwnerRecord>> listOwners({int limit = 100}) async {
    try {
      final rows = await _client
          .from('organizations')
          .select(
            'id, name, owner_user_id, org_type, city, identity_verification, business_verification, is_active',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => AdminOwnerRecord(
              id: row['id'] as String? ?? '',
              name: row['name'] as String? ?? '',
              ownerUserId: row['owner_user_id'] as String? ?? '',
              orgType: row['org_type'] as String? ?? '',
              city: row['city'] as String? ?? '',
              identityVerification:
                  row['identity_verification'] as String? ?? '',
              businessVerification:
                  row['business_verification'] as String? ?? '',
              isActive: row['is_active'] as bool? ?? true,
            ),
          )
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<AdminVenueRecord>> listVenues({int limit = 100}) async {
    try {
      final venues = await inspectableVenues(limit: limit);
      return venues
          .map(
            (venue) => AdminVenueRecord(
              id: venue.id,
              name: venue.name,
              city: venue.city,
              isActive: venue.isActive,
              avgRating: venue.avgRating,
              ratingCount: venue.ratingCount,
            ),
          )
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Event>> listPublishedEvents({int limit = 50}) async {
    try {
      final rows = await _client
          .from('events')
          .select('*')
          .eq('status', 'published')
          .order('starts_at', ascending: true)
          .limit(limit);
      return rows.whereType<Map<String, dynamic>>().map(Event.fromJson).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Course>> listPublishedCourses({int limit = 50}) async {
    try {
      final rows = await _client
          .from('courses')
          .select('*')
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Course.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<SupportTicket>> listSupportTickets({int limit = 100}) async {
    try {
      final rows = await _client
          .from('support_tickets')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(SupportTicket.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<SupportTicket> resolveTicket(String ticketId) async {
    try {
      final row = await _client.rpc<dynamic>(
        'mark_ticket_resolved',
        params: {'p_ticket_id': ticketId},
      );
      if (row is Map<String, dynamic>) {
        return SupportTicket.fromJson(row);
      }
      if (row is List && row.isNotEmpty && row.first is Map) {
        return SupportTicket.fromJson(
          Map<String, dynamic>.from(row.first as Map),
        );
      }
      throw const app_errors.ServerException(
        'Support ticket could not be resolved.',
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Venue>> inspectableVenues({int limit = 100}) async {
    try {
      final rows = await _client
          .from('venues')
          .select('id, name, city, is_active, avg_rating, rating_count')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map<String, dynamic>>().map(Venue.fromJson).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
