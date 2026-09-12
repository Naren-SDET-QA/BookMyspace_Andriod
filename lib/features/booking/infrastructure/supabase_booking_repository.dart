import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/booking.dart';
import '../domain/booking_repository.dart';

/// Supabase-backed [BookingRepository].
///
/// Availability and holds are authoritative server operations. This class
/// deliberately has no local booking or slot fallback: a booking must be
/// created and returned by Supabase before the payment flow can start.
class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._client);

  final SupabaseClient _client;

  static const String _slotSelect = '''
    *,
    venues (id, name, city),
    time_slots (id, label)
  ''';

  @override
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  }) async {
    try {
      final data = await _client.rpc<List<dynamic>>(
        'available_time_slots',
        params: {'p_venue_id': venueId, 'p_book_date': _formatDate(date)},
      );
      return data
          .whereType<Map<String, dynamic>>()
          .map(SlotAvailability.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-booking-hold',
        body: {
          'venue_id': venueId,
          'slot_id': slotId,
          'book_date': _formatDate(bookDate),
          'idempotency_key': _newUuid(),
          'amount': amount,
          'hold_minutes': holdMinutes,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const app_errors.ServerException(
          'Booking service returned an empty hold response.',
          code: 'empty_hold_response',
        );
      }
      return BookingHold.fromResponse(data);
    } on FunctionException catch (e) {
      final details = e.details;
      final error = details is Map<String, dynamic>
          ? (details['error'] as String? ?? '')
          : '';
      if (error == 'slot_unavailable') {
        throw const app_errors.BookingConflictException(
          'This slot was just taken. Please pick another.',
          code: 'slot_unavailable',
        );
      }
      throw app_errors.ServerException(
        'Booking service error (${e.status}).',
        code: error,
        statusCode: e.status,
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking> createBooking({
    required BookingHold hold,
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    required double taxAmount,
    required double totalAmount,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const app_errors.AuthException('You must be signed in to book.');
      }

      // Store the authoritative slot times rather than client defaults.
      final slot = await _client
          .from('time_slots')
          .select('label, start_time, end_time')
          .eq('id', slotId)
          .maybeSingle();
      if (slot == null) {
        throw const app_errors.NotFoundException(
          'The selected time slot no longer exists.',
          code: 'slot_not_found',
        );
      }

      final row = await _client
          .from('bookings')
          .insert({
            'booking_ref': _bookingRef(),
            'user_id': user.id,
            'venue_id': venueId,
            'slot_id': slotId,
            'book_date': _formatDate(bookDate),
            'start_time': slot['start_time'],
            'end_time': slot['end_time'],
            'hold_id': hold.id,
            'status': 'pending',
            'quantity': 1,
            'amount': amount,
            'tax_amount': taxAmount,
            'total_amount': totalAmount,
            'currency': 'INR',
          })
          .select(_slotSelect)
          .single();
      return Booking.fromJson(row);
    } on PostgrestException catch (e) {
      // 23P01 = the deployed bookings_no_overlap constraint.
      if (e.code == '23P01') {
        throw const app_errors.BookingConflictException(
          'This slot is no longer available.',
          code: 'slot_unavailable',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Booking>> myBookings() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const [];
      final rows = await _client
          .from('bookings')
          .select(_slotSelect)
          .eq('user_id', user.id)
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
  Future<List<Booking>> ownerVenueBookings() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const [];
      final rows = await _client
          .from('bookings')
          .select(_slotSelect)
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
  Future<void> cancelBooking(String bookingId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const app_errors.AuthException(
          'You must be signed in to cancel.',
        );
      }
      final booking = await _client
          .from('bookings')
          .select('hold_id')
          .eq('id', bookingId)
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .maybeSingle();
      if (booking == null) {
        throw const app_errors.BookingConflictException(
          'This booking can no longer be cancelled.',
          code: 'cannot_cancel',
        );
      }
      final result = await _client
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', bookingId)
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .select('id');
      if (result.isEmpty) {
        throw const app_errors.BookingConflictException(
          'This booking can no longer be cancelled.',
          code: 'cannot_cancel',
        );
      }

      // Release the active hold immediately. If the release call fails, the
      // server-side expiry job still frees it; surface the partial failure so
      // the UI never implies that every write completed successfully.
      final holdId = booking['hold_id'] as String?;
      if (holdId != null && holdId.isNotEmpty) {
        try {
          await _client.rpc(
            'release_venue_hold',
            params: {'p_hold_id': holdId, 'p_user_id': user.id},
          );
        } catch (_) {
          throw app_errors.ServerException(
            'Booking cancelled, but the slot release is still processing.',
            code: 'hold_release_failed',
          );
        }
      }
    } catch (e) {
      if (e is app_errors.BookingConflictException) rethrow;
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking> checkInBooking(String qrOrRef) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const app_errors.AuthException(
          'You must be signed in to check in a booking.',
        );
      }

      final code = _bookingCode(qrOrRef);
      if (code.isEmpty) {
        throw const app_errors.ValidationException(
          'The booking pass is empty or invalid.',
          code: 'invalid_booking_pass',
        );
      }

      final response = await _client.rpc(
        'check_in_booking',
        params: {'p_code': code, 'p_method': 'qr'},
      );
      final data = response is Map<String, dynamic> ? response : null;
      final bookingId = data?['booking_id'] as String?;
      if (bookingId == null || bookingId.isEmpty) {
        throw const app_errors.NotFoundException(
          'The booking pass could not be validated.',
          code: 'booking_not_found_or_not_owner',
        );
      }

      final row = await _client
          .from('bookings')
          .select(_slotSelect)
          .eq('id', bookingId)
          .maybeSingle();
      if (row == null) {
        throw const app_errors.NotFoundException(
          'The checked-in booking could not be loaded.',
          code: 'booking_not_found',
        );
      }
      return Booking.fromJson(row);
    } on PostgrestException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  static String _bookingCode(String raw) {
    final clean = raw.trim();
    if (!clean.startsWith('{')) return clean;
    try {
      final decoded = jsonDecode(clean);
      if (decoded is Map<String, dynamic>) {
        return (decoded['booking_id'] as String? ?? '').trim();
      }
    } catch (_) {
      // The validation error below is the user-facing result.
    }
    return '';
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _bookingRef() {
    final n = Random().nextInt(0xFFFFFF);
    return 'BMS-${n.toRadixString(16).toUpperCase().padLeft(6, '0')}';
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
}
