import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../auth/presentation/auth_providers.dart';
import '../domain/course.dart';

/// Owner batch editor save: every batch field, including waitlist and the
/// highlight fields, in one upsert. RLS (`course_batches_owner_*`) limits
/// writes to the owning institute. Returns the batch id.
class BatchEditorWriter {
  BatchEditorWriter(this._client);

  final SupabaseClient _client;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<String> save(CourseBatch b) async {
    if (b.label.trim().isEmpty) {
      throw const app_errors.ValidationException('Batch title is required.');
    }
    if (b.capacity < 1) {
      throw const app_errors.ValidationException(
        'Capacity must be at least 1.',
      );
    }
    try {
      final row = await _client
          .from('course_batches')
          .upsert({
            if (b.id.isNotEmpty) 'id': b.id,
            'course_id': b.courseId,
            'label': b.label.trim(),
            'starts_on': _date(b.startsOn),
            'ends_on': b.endsOn == null ? null : _date(b.endsOn!),
            'capacity': b.capacity,
            'is_active': b.isActive,
            'timing': b.timing.trim(),
            'fee_amount': b.feeAmount,
            if (b.mode != null) 'mode': b.mode!.dbValue,
            'waitlist_enabled': b.waitlistEnabled,
            'admissions_open': b.admissionsOpen,
            'subject': b.subject.trim(),
            'category_slug': b.categorySlug,
            'todays_topic': b.todaysTopic.trim(),
            'highlight_tag': b.highlightTag.trim(),
            'days_of_week': b.daysOfWeek,
            'age_group': b.ageGroup.trim(),
            'skill_level': b.skillLevel,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}

final batchEditorWriterProvider = Provider<BatchEditorWriter>(
  (ref) => BatchEditorWriter(ref.watch(supabaseProvider)),
);
