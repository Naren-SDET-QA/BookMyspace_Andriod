import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../booking/domain/booking.dart';
import '../domain/owner_booking_repository.dart';

/// Supabase-backed [OwnerBookingRepository].
class SupabaseOwnerBookingRepository implements OwnerBookingRepository {
  SupabaseOwnerBookingRepository(this._client);

  final SupabaseClient _client;

  static const String _bookingSelect = '''
    *,
    venues (id, name, city),
    time_slots (id, label),
    payments (method, provider_payment_id, status, created_at)
  ''';

  @override
  Future<List<Booking>> myVenueBookings() async {
    try {
      final venueRows = await _client.rpc<List<dynamic>>('get_owner_venues');
      final ids = venueRows
          .whereType<Map<String, dynamic>>()
          .map((v) => v['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (ids.isEmpty) return const [];
      final rows = await _client
          .from('bookings')
          .select(_bookingSelect)
          .inFilter('venue_id', ids)
          .order('book_date', ascending: false)
          .order('start_time', ascending: false);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking> createOfflineBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required String customerName,
    required String customerPhone,
    required double amount,
    required double taxAmount,
    required double totalAmount,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'owner-booking-manage',
        body: {
          'action': 'create_offline',
          'venue_id': venueId,
          'slot_id': slotId,
          'book_date': _formatDate(bookDate),
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'amount': amount,
          'tax_amount': taxAmount,
          'total_amount': totalAmount,
          'idempotency_key': offlineIdempotencyKey(
            venueId: venueId,
            slotId: slotId,
            bookDate: bookDate,
            customerPhone: customerPhone,
          ),
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['booking'] is! Map<String, dynamic>) {
        throw const app_errors.ServerException(
          'Owner booking service returned an empty response.',
          code: 'empty_owner_booking_response',
        );
      }
      return Booking.fromJson(
        Map<String, dynamic>.from(data['booking'] as Map),
      );
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking> updateStatus(
    String bookingId,
    OwnerBookingAction action,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'owner-booking-manage',
        body: {
          'action': 'update_status',
          'booking_id': bookingId,
          'status_action': action.dbValue,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['booking'] is! Map<String, dynamic>) {
        throw const app_errors.ServerException(
          'Owner booking service returned an empty response.',
          code: 'empty_owner_booking_response',
        );
      }
      return Booking.fromJson(
        Map<String, dynamic>.from(data['booking'] as Map),
      );
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<BookingDecisionOutcome> decideBooking(
    String bookingId,
    OwnerBookingDecision decision, {
    String? reason,
  }) async {
    final trimmedReason = reason?.trim();
    try {
      final current = await _client
          .from('bookings')
          .select('status')
          .eq('id', bookingId)
          .maybeSingle();
      if (current?['status'] == 'awaiting_owner_approval') {
        return await _decideRequest(bookingId, decision, trimmedReason);
      }
      final response = await _client.functions.invoke(
        'owner-booking-manage',
        body: {
          'action': decision.dbValue,
          'booking_id': bookingId,
          if (decision == OwnerBookingDecision.reject &&
              trimmedReason != null &&
              trimmedReason.isNotEmpty)
            'reason': trimmedReason,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const app_errors.ServerException(
          'Owner booking service returned an empty response.',
          code: 'empty_owner_booking_response',
        );
      }
      // The decision endpoint returns the RPC's lightweight result
      // ({status, booking_id, order_id?, approval_event_id, refund_status?}),
      // not a full booking row (unlike update_status), so re-fetch the
      // booking the same way myVenueBookings() does to hand the UI a
      // fully-populated Booking.
      final row = await _client
          .from('bookings')
          .select(_bookingSelect)
          .eq('id', bookingId)
          .single();
      return BookingDecisionOutcome(
        booking: Booking.fromJson(row),
        refundStatus: data['refund_status'] as String?,
      );
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  /// Decides a pre-payment booking request (`awaiting_owner_approval`)
  /// through the approval RPCs; `reject_venue_booking` stores [reason] in
  /// `bookings.rejection_reason`.
  Future<BookingDecisionOutcome> _decideRequest(
    String bookingId,
    OwnerBookingDecision decision,
    String? reason,
  ) async {
    final isApprove = decision == OwnerBookingDecision.approve;
    final response = await _client.rpc<dynamic>(
      isApprove ? 'approve_venue_booking' : 'reject_venue_booking',
      params: {
        'p_booking_id': bookingId,
        'p_idempotency_key': _newUuid(),
        if (!isApprove)
          'p_reason': (reason == null || reason.isEmpty) ? null : reason,
      },
    );
    if (response is Map && response['success'] == false) {
      final code = response['error_code']?.toString() ?? 'decision_failed';
      throw app_errors.BusinessException(
        code == 'INVALID_STATUS'
            ? 'This booking cannot be moved to that status.'
            : code == 'NOT_OWNER_OR_NOT_FOUND'
            ? 'You are not allowed to manage this booking.'
            : 'The booking decision could not be saved ($code).',
        code: code,
      );
    }
    final row = await _client
        .from('bookings')
        .select(_bookingSelect)
        .eq('id', bookingId)
        .single();
    return BookingDecisionOutcome(booking: Booking.fromJson(row));
  }

  static String _newUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }

  app_errors.AppException _mapFunctionException(FunctionException e) {
    final details = e.details;
    final error = details is Map<String, dynamic>
        ? (details['error'] as String? ?? '')
        : '';
    return switch (error) {
      'booking_not_found' || 'venue_not_found' => app_errors.NotFoundException(
        'The booking could not be found.',
        code: error,
        statusCode: e.status,
      ),
      'not_owner' => app_errors.BusinessException(
        'You are not allowed to manage this booking.',
        code: error,
        statusCode: e.status,
      ),
      'slot_unavailable' => const app_errors.BookingConflictException(
        'This slot is no longer available.',
        code: 'slot_unavailable',
      ),
      'invalid_transition' => app_errors.BusinessException(
        'This booking cannot be moved to that status.',
        code: error,
        statusCode: e.status,
      ),
      'confirmed_payment_required' => app_errors.BusinessException(
        'Online bookings must be cancelled through the customer refund flow.',
        code: error,
        statusCode: e.status,
      ),
      'amount_mismatch' => app_errors.BusinessException(
        'The amounts do not match the venue pricing.',
        code: error,
        statusCode: e.status,
      ),
      _ => app_errors.ServerException(
        'Owner booking service error (${e.status}).',
        code: error,
        statusCode: e.status,
      ),
    };
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String offlineIdempotencyKey({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required String customerPhone,
  }) {
    final raw = [
      venueId,
      slotId,
      _formatDate(bookDate),
      customerPhone.trim(),
    ].join('|');
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  }
}
