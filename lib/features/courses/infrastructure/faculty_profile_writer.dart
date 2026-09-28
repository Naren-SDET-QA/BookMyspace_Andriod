import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../auth/presentation/auth_providers.dart';
import '../domain/course.dart';

/// Owner edits of an existing faculty profile. RLS
/// (`course_faculty_org_write`) limits writes to the owning institute.
class FacultyProfileWriter {
  FacultyProfileWriter(this._client);

  final SupabaseClient _client;

  Future<void> update(CourseFaculty f) async {
    if (f.id.isEmpty) {
      throw const app_errors.ValidationException('Missing faculty id.');
    }
    if (f.name.trim().isEmpty) {
      throw const app_errors.ValidationException('Name is required.');
    }
    try {
      final changed = await _client
          .from('course_faculty')
          .update({
            'name': f.name.trim(),
            'designation': f.designation.trim(),
            'role': f.role.trim(),
            'qualification': f.qualification.trim(),
            'specialization': f.specialization.trim(),
            'experience_text': f.experienceText.trim(),
            'bio': f.bio.trim(),
            'demo_url': f.demoUrl.trim(),
            'skills': f.skills,
            'languages': f.languages,
            'certifications': f.certifications,
            'awards': f.achievements,
            'students_trained': f.studentsTrained,
            'teaching_philosophy': f.teachingPhilosophy.trim(),
          })
          .eq('id', f.id)
          .select('id')
          .maybeSingle();
      if (changed == null) {
        throw const app_errors.BusinessException(
          'You can only edit faculty of your own institute.',
          code: 'faculty_forbidden',
        );
      }
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}

final facultyProfileWriterProvider = Provider<FacultyProfileWriter>(
  (ref) => FacultyProfileWriter(ref.watch(supabaseProvider)),
);
