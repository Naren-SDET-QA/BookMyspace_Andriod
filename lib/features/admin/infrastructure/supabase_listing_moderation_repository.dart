import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exceptions.dart'
    show BusinessException, mapError;
import '../domain/listing_moderation.dart';
import '../domain/listing_moderation_repository.dart';

class SupabaseListingModerationRepository
    implements ListingModerationRepository, ListingLifecycleRepository {
  SupabaseListingModerationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ModeratedListing>> listings({String? status}) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'admin_list_listings',
        params: {'p_status': status},
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(ModeratedListing.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<ModeratedListing> moderate({
    required String venueId,
    required String action,
    String? reason,
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'admin_moderate_listing',
        params: {'p_venue_id': venueId, 'p_action': action, 'p_reason': reason},
      );
      return ModeratedListing.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<ModeratedListing> submitForReview(String venueId) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'submit_listing_for_review',
        params: {'p_venue_id': venueId},
      );
      return ModeratedListing.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<OversightRow>> bookings({int limit = 50}) async {
    try {
      final rows = await _client
          .from('bookings')
          .select(
            'id, booking_ref, status, total_amount, created_at, user_id, '
            'metadata, venues(name, organizations(name, owner_user_id))',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      final maps = rows.whereType<Map<String, dynamic>>().toList();
      String? ownerIdOf(Map<String, dynamic> row) {
        final venue = row['venues'];
        final org = venue is Map ? venue['organizations'] : null;
        return org is Map ? org['owner_user_id'] as String? : null;
      }

      final profiles = await _profilesFor({
        ...maps.map((r) => r['user_id'] as String? ?? ''),
        ...maps.map((r) => ownerIdOf(r) ?? ''),
      });
      return maps.map((row) {
        final venue = row['venues'];
        final name = venue is Map ? venue['name']?.toString() ?? '' : '';
        final owner = ownerDetails(
          organization: venue is Map ? venue['organizations'] : null,
          ownerProfile: profiles[ownerIdOf(row)],
        );
        final id = row['id'] as String? ?? '';
        final ref = row['booking_ref'] as String? ?? '';
        final metadata = row['metadata'];
        final meta = metadata is Map ? metadata : const {};
        final profile = profiles[row['user_id']] ?? const <String, dynamic>{};
        final offlineName = meta['customer_name']?.toString() ?? '';
        final customer = offlineName.isNotEmpty
            ? offlineName
            : profile['full_name']?.toString() ?? '';
        final offlinePhone = meta['customer_phone']?.toString() ?? '';
        final contact = offlinePhone.isNotEmpty
            ? offlinePhone
            : (profile['email'] ?? profile['phone'])?.toString() ?? '';
        return OversightRow(
          id: id,
          title: name.isEmpty ? 'Booking' : name,
          subtitle: ref.isNotEmpty
              ? ref
              : id.substring(0, id.length < 8 ? id.length : 8),
          status: row['status'] as String? ?? '',
          amount: (row['total_amount'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
          reference: ref,
          customerName: customer,
          customerContact: contact,
          ownerName: owner.name,
          ownerContact: owner.contact,
        );
      }).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Owner shown on an admin booking card, from the booking's venue
  /// organization (`organizations(name, owner_user_id)`) and the owner's
  /// `profiles` row. Name: profile full name, else organization name.
  /// Contact: phone and/or email, joined with " · "; empty when neither is
  /// known.
  static ({String name, String contact}) ownerDetails({
    Object? organization,
    Map<String, dynamic>? ownerProfile,
  }) {
    String text(Object? value) => value?.toString().trim() ?? '';
    final orgName = organization is Map ? text(organization['name']) : '';
    final fullName = text(ownerProfile?['full_name']);
    final contact = [
      text(ownerProfile?['phone']),
      text(ownerProfile?['email']),
    ].where((s) => s.isNotEmpty).join(' · ');
    return (name: fullName.isNotEmpty ? fullName : orgName, contact: contact);
  }

  /// Best-effort customer lookup for booking rows (bookings.user_id
  /// references auth.users, so profiles cannot be embedded). Missing
  /// permissions just leave the customer column blank.
  Future<Map<String, Map<String, dynamic>>> _profilesFor(
    Set<String> userIds,
  ) async {
    final ids = userIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, email, phone')
          .inFilter('id', ids);
      return {
        for (final row in rows.whereType<Map<String, dynamic>>())
          row['id'] as String? ?? '': row,
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> adminCancelBooking({
    required String bookingId,
    required String reason,
    double? refundAmount,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'admin_cancel_booking',
        params: {
          'p_booking_id': bookingId,
          'p_refund_amount': refundAmount,
          'p_reason': reason.trim(),
        },
      );
      if (response is Map && response['success'] == false) {
        final code = response['error_code']?.toString() ?? 'CANCEL_FAILED';
        throw BusinessException(_adminCancelMessage(code), code: code);
      }
    } catch (e) {
      throw mapError(e);
    }
  }

  static String _adminCancelMessage(String code) => switch (code) {
    'REASON_REQUIRED' => 'A cancellation reason is required.',
    'NOT_AUTHORIZED' => 'Only platform administrators can cancel bookings.',
    'BOOKING_NOT_FOUND' => 'The booking could not be found.',
    'CANNOT_CANCEL' => 'Only confirmed bookings can be cancelled by admin.',
    'INVALID_AMOUNT' => 'Refund amount cannot be negative.',
    'NO_CAPTURED_PAYMENT' => 'There is no captured payment to refund.',
    'AMOUNT_EXCEEDS_CAPTURED' => 'Refund amount exceeds the captured payment.',
    _ => 'Booking cancellation failed ($code).',
  };

  @override
  Future<void> adminApproveBooking(String bookingId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'approve_venue_booking',
        params: {
          'p_booking_id': bookingId,
          'p_idempotency_key': const Uuid().v4(),
        },
      );
      _throwIfDecisionFailed(response, fallback: 'APPROVAL_FAILED');
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> adminRejectBooking(
    String bookingId, {
    required String reason,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const BusinessException(
        'A reason is required to decline a request.',
        code: 'REASON_REQUIRED',
      );
    }
    try {
      final response = await _client.rpc<dynamic>(
        'reject_venue_booking',
        params: {
          'p_booking_id': bookingId,
          'p_idempotency_key': const Uuid().v4(),
          'p_reason': trimmed,
        },
      );
      _throwIfDecisionFailed(response, fallback: 'REJECTION_FAILED');
    } catch (e) {
      throw mapError(e);
    }
  }

  static void _throwIfDecisionFailed(
    Object? response, {
    required String fallback,
  }) {
    if (response is Map && response['success'] == false) {
      final code = response['error_code']?.toString() ?? fallback;
      throw BusinessException(adminDecisionMessage(code), code: code);
    }
  }

  /// User-facing text for the error codes returned by
  /// `approve_venue_booking` / `reject_venue_booking`.
  static String adminDecisionMessage(String code) => switch (code) {
    'ALREADY_PROCESSED' => 'This request has already been processed.',
    'INVALID_STATUS' => 'This request is no longer awaiting approval.',
    'APPROVAL_EXPIRED' =>
      'The approval window expired. The slot was released.',
    'SLOT_UNAVAILABLE' =>
      'Availability changed. This request cannot be approved.',
    'EXTERNALLY_BOOKED' =>
      'This slot was booked through an external channel.',
    'NOT_OWNER_OR_NOT_FOUND' =>
      'You are not allowed to decide this request.',
    _ => 'The decision could not be saved ($code).',
  };

  @override
  Future<List<OversightRow>> payments({int limit = 50}) async {
    try {
      final rows = await _client
          .from('payments')
          .select('id, status, amount, currency, created_at, booking_id')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map<String, dynamic>>().map((row) {
        return OversightRow(
          id: row['id'] as String? ?? '',
          title: 'Payment ${row['currency'] ?? 'INR'}',
          subtitle: row['booking_id'] as String? ?? '',
          status: row['status'] as String? ?? '',
          amount: (row['amount'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<OversightRow>> refunds({int limit = 50}) async {
    try {
      final rows = await _client
          .from('refunds')
          .select('id, status, amount, created_at, payment_id')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map<String, dynamic>>().map((row) {
        return OversightRow(
          id: row['id'] as String? ?? '',
          title: 'Refund',
          subtitle: row['payment_id'] as String? ?? '',
          status: row['status'] as String? ?? '',
          amount: (row['amount'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
        );
      }).toList();
    } catch (e) {
      throw mapError(e);
    }
  }
}
