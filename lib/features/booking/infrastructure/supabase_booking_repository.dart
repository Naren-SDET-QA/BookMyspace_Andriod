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
    time_slots (id, label),
    booking_receipts (receipt_number, issued_at)
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
      // Root cause of the `[missing_auth] Booking service error (401)`
      // seen on Confirm Booking: `_client.functions.invoke` sends whatever
      // Authorization header the FunctionsClient last cached from an auth
      // state event (signedIn/tokenRefreshed). A silently restored session
      // on cold start, or a session that expired between screens, can leave
      // that cached header stale or absent even though the user is (or was)
      // signed in -- the Edge Function then sees no Authorization header at
      // all and returns 401 missing_auth before it ever reaches RLS. Fix:
      // resolve and attach the current session's access token explicitly on
      // every call, refreshing it once if it has expired, and fail fast with
      // a clear AuthException (never a fabricated token) if no valid session
      // is available -- rather than silently sending an unauthenticated
      // request and surfacing a confusing server-side 401.
      final session = await _requireValidSession();
      final response = await _client.functions.invoke(
        'create-booking-hold',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {
          'venue_id': venueId,
          'slot_id': slotId,
          'book_date': _formatDate(bookDate),
          'idempotency_key': _newUuid(),
          'amount': amount,
          'hold_minutes': holdMinutes,
          'approval_minutes': holdMinutes,
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
      if (error == 'date_blocked') {
        throw const app_errors.BookingConflictException(
          'This venue is unavailable on the selected date.',
          code: 'date_blocked',
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
  Future<Booking> requestBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int approvalMinutes = 120,
  }) async {
    final hold = await acquireHold(
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      amount: amount,
      holdMinutes: approvalMinutes,
    );
    final bookingId = hold.bookingId;
    if (bookingId == null || bookingId.isEmpty) {
      throw const app_errors.ServerException(
        'Booking request did not return a server booking.',
        code: 'missing_booking_id',
      );
    }
    return _loadBooking(bookingId);
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
    // The hold endpoint now creates the booking request atomically. Retain
    // this method for the existing repository contract, but never recreate a
    // booking with a client-side insert (which could bypass approval/RLS).
    final bookingId = hold.bookingId;
    if (bookingId == null || bookingId.isEmpty) {
      throw const app_errors.ServerException(
        'The server did not return an approval request.',
        code: 'missing_booking_id',
      );
    }
    return _loadBooking(bookingId);
  }

  @override
  Future<Booking> approveBooking(String bookingId) async {
    try {
      final response = await _client.rpc(
        'approve_venue_booking',
        params: {
          'p_booking_id': bookingId,
          'p_idempotency_key': _newUuid(),
        },
      );
      _ensureRpcSuccess(response, fallbackCode: 'approval_failed');
      return _loadBooking(bookingId);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking> rejectBooking(String bookingId, {String? reason}) async {
    try {
      final response = await _client.rpc(
        'reject_venue_booking',
        params: {
          'p_booking_id': bookingId,
          'p_idempotency_key': _newUuid(),
          'p_reason': reason,
        },
      );
      _ensureRpcSuccess(response, fallbackCode: 'rejection_failed');
      return _loadBooking(bookingId);
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
  Future<List<Booking>> recentBookings({int limit = 5}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const [];
      final rows = await _client
          .from('bookings')
          .select(_slotSelect)
          .eq('user_id', user.id)
          .order('book_date', ascending: false)
          .order('start_time', ascending: false)
          .order('id', ascending: true)
          .limit(limit);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Booking>> myBookingsPage({
    required int offset,
    required int limit,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return const [];
      final safeOffset = offset < 0 ? 0 : offset;
      final safeLimit = limit < 1 ? 1 : limit;
      // Phase 9XM-3: same ordering as myBookings() (book_date desc,
      // start_time desc), with `id` added as a deterministic tiebreaker.
      // Without a tiebreaker, rows that share the same (book_date,
      // start_time) have no guaranteed stable order across separate
      // .range() requests, which could duplicate or skip rows between
      // pages. The `id` order is arbitrary but stable, and never affects
      // the visible newest-first ordering for rows with distinct
      // (book_date, start_time).
      final rows = await _client
          .from('bookings')
          .select(_slotSelect)
          .eq('user_id', user.id)
          .order('book_date', ascending: false)
          .order('start_time', ascending: false)
          .order('id', ascending: true)
          .range(safeOffset, safeOffset + safeLimit - 1);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Booking.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Booking?> bookingById(String bookingId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final row = await _client
          .from('bookings')
          .select(_slotSelect)
          .eq('id', bookingId)
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) return null;
      return Booking.fromJson(row);
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
      final response = await _client.rpc(
        'cancel_venue_booking',
        params: {'p_booking_id': bookingId},
      );
      _ensureRpcSuccess(response, fallbackCode: 'cannot_cancel');
    } catch (e) {
      if (e is app_errors.BookingConflictException) rethrow;
      throw app_errors.mapError(e);
    }
  }

  /// Resolves the current Supabase session, refreshing it once if it has
  /// expired, and never fabricating or bypassing auth: a missing or
  /// unrefreshable session is surfaced as an explicit [app_errors.AuthException]
  /// instead of letting the request go out without a valid user token.
  Future<Session> _requireValidSession() async {
    var session = _client.auth.currentSession;
    if (session == null) {
      throw const app_errors.AuthException(
        'You must be signed in to book. Please sign in and try again.',
        code: 'missing_session',
      );
    }
    final expiresAt = session.expiresAt;
    final isExpired = expiresAt != null &&
        DateTime.now().toUtc().isAfter(
              DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000,
                  isUtc: true),
            );
    if (isExpired) {
      try {
        final refreshed = await _client.auth.refreshSession();
        session = refreshed.session;
      } catch (_) {
        session = null;
      }
      if (session == null) {
        throw const app_errors.AuthException(
          'Your session has expired. Please sign in again to continue booking.',
          code: 'expired_session',
        );
      }
    }
    return session;
  }

  Future<Booking> _loadBooking(String bookingId) async {
    final row = await _client
        .from('bookings')
        .select(_slotSelect)
        .eq('id', bookingId)
        .maybeSingle();
    if (row == null) {
      throw const app_errors.NotFoundException(
        'The server booking could not be loaded.',
        code: 'booking_not_found',
      );
    }
    return Booking.fromJson(row);
  }

  static void _ensureRpcSuccess(
    dynamic response, {
    required String fallbackCode,
  }) {
    if (response is Map<String, dynamic> && response['success'] == true) {
      return;
    }
    final code = response is Map<String, dynamic>
        ? response['error_code']?.toString().toLowerCase()
        : null;
    throw app_errors.ServerException(
      response is Map<String, dynamic> && response['message'] is String
          ? response['message'] as String
          : 'The server rejected this booking operation.',
      code: code ?? fallbackCode,
    );
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
