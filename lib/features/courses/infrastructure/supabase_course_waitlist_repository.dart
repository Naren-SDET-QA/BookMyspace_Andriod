import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/course_waitlist.dart';

/// Calls the `join_course_waitlist` / `leave_course_waitlist` /
/// `my_course_waitlist` RPCs. All queue state lives in the database.
class SupabaseCourseWaitlistRepository implements CourseWaitlistRepository {
  SupabaseCourseWaitlistRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<int> join(String batchId) async {
    if (_client.auth.currentUser == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      final raw = await _client.rpc<dynamic>(
        'join_course_waitlist',
        params: {'p_batch_id': batchId},
      );
      return (raw as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      throw _map(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> leave(String batchId) async {
    try {
      await _client.rpc<dynamic>(
        'leave_course_waitlist',
        params: {'p_batch_id': batchId},
      );
    } on PostgrestException catch (e) {
      throw _map(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<CourseWaitlistEntry>> mine() async {
    if (_client.auth.currentUser == null) return const [];
    try {
      final rows = await _client.rpc<dynamic>('my_course_waitlist');
      return (rows as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CourseWaitlistEntry.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      // Older schemas without the waitlist RPCs: no entries.
      if (e.code == 'PGRST202' || e.code == '42883') return const [];
      throw app_errors.mapError(e);
    }
  }

  app_errors.AppException _map(PostgrestException e) {
    final m = e.message.toLowerCase();
    if (m.contains('seats available')) {
      return const app_errors.BusinessException(
        'Seats are available now. Enroll directly instead.',
        code: 'seats_available',
      );
    }
    if (m.contains('waitlist not enabled')) {
      return const app_errors.BusinessException(
        'This batch does not have a waitlist.',
        code: 'waitlist_disabled',
      );
    }
    if (m.contains('already enrolled')) {
      return const app_errors.BusinessException(
        'You are already enrolled in this batch.',
        code: 'duplicate_enrollment',
      );
    }
    if (m.contains('batch not available')) {
      return const app_errors.BusinessException(
        'This batch is no longer available.',
        code: 'batch_unavailable',
      );
    }
    return app_errors.mapError(e);
  }
}
