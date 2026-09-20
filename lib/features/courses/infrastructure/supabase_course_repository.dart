import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/course.dart';
import '../domain/course_repository.dart';

/// Supabase-backed [CourseRepository] against live `courses`,
/// `course_batches`, `institutes`, and enrollment RPCs.
///
/// Education profile columns and the `course_faculty` / `course_feedback` /
/// `course_demo_registrations` tables are additive. Schemas that predate the
/// education migration omit them, so every extended select or insert is
/// attempted first and degrades to the base shape on failure.
class SupabaseCourseRepository implements CourseRepository {
  SupabaseCourseRepository(this._client);

  final SupabaseClient _client;

  static const String _baseCourseSelect = '''
    *,
    institutes (id, org_id, name, description, logo_image, is_verified),
    course_batches (id, course_id, label, starts_on, capacity, enrolled_count, is_active)
  ''';

  static const String _extendedCourseSelect = '''
    *,
    institutes (id, org_id, name, description, logo_image, is_verified, institute_type, category_id, address, city, latitude, longitude, phone, email, whatsapp, website, mode, timings, images, amenities),
    course_batches (id, course_id, label, starts_on, capacity, enrolled_count, is_active, timing, ends_on, fee_amount, mode, waitlist_enabled, waitlist_count, admissions_open, subject, category_slug),
    course_faculty (id, course_id, name, role, bio, photo_url),
    course_faqs (id, course_id, question, answer, display_order)
  ''';

  String? get _userId => _client.auth.currentUser?.id;

  bool _isMissingRelation(Object e) {
    if (e is PostgrestException) {
      final m = e.message.toLowerCase();
      return e.code == '42P01' ||
          e.code == '42703' ||
          m.contains('does not exist');
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _selectCourses(
    Future<List<dynamic>> Function(String select) query,
  ) async {
    try {
      final rows = await query(_extendedCourseSelect);
      return rows.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      if (!_isMissingRelation(e)) rethrow;
      final rows = await query(_baseCourseSelect);
      return rows.whereType<Map<String, dynamic>>().toList();
    }
  }

  Future<Set<String>> _myEnrolledBatchIds() async {
    final userId = _userId;
    if (userId == null) return const {};
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'my_enrolled_batches',
        params: {'p_user_id': userId},
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map((r) => (r['batch_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } on PostgrestException catch (e) {
      if (e.code == '42501') return const {};
      throw app_errors.mapError(e);
    }
  }

  Course _mergeEnrollments(Course course, Set<String> enrolled) {
    if (enrolled.isEmpty) return course;
    return course.copyWith(
      batches: course.batches
          .map(
            (batch) => enrolled.contains(batch.id)
                ? batch.copyWith(userEnrolled: true)
                : batch,
          )
          .toList(),
    );
  }

  @override
  Future<List<Course>> publishedCourses() async {
    try {
      final enrolled = await _myEnrolledBatchIds();
      final rows = await _selectCourses(
        (select) => _client
            .from('courses')
            .select(select)
            .eq('status', 'published')
            .order('created_at', ascending: false),
      );
      return rows
          .map((row) => _mergeEnrollments(Course.fromJson(row), enrolled))
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Course> courseDetail(String courseId) async {
    try {
      final enrolled = await _myEnrolledBatchIds();
      final rows = await _selectCourses(
        (select) => _client.from('courses').select(select).eq('id', courseId),
      );
      if (rows.isEmpty) {
        throw const app_errors.NotFoundException(
          'Course not found',
          code: 'not_found',
        );
      }
      return _mergeEnrollments(Course.fromJson(rows.first), enrolled);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const app_errors.NotFoundException(
          'Course not found',
          code: 'not_found',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Institute>> institutes() async {
    try {
      final rows = await _client
          .from('institutes')
          .select('*')
          .order('name', ascending: true);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Institute.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Institute> instituteDetail(String instituteId) async {
    try {
      final row = await _client
          .from('institutes')
          .select('*')
          .eq('id', instituteId)
          .maybeSingle();
      if (row == null) {
        throw const app_errors.NotFoundException(
          'Institute not found',
          code: 'not_found',
        );
      }
      return Institute.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const app_errors.NotFoundException(
          'Institute not found',
          code: 'not_found',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Course>> coursesForInstitute(String instituteId) async {
    try {
      final enrolled = await _myEnrolledBatchIds();
      final rows = await _selectCourses(
        (select) => _client
            .from('courses')
            .select(select)
            .eq('institute_id', instituteId)
            .eq('status', 'published')
            .order('created_at', ascending: false),
      );
      return rows
          .map((row) => _mergeEnrollments(Course.fromJson(row), enrolled))
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<MyEnrolledCourse>> myEnrolledCourses() async {
    final courses = await publishedCourses();
    final result = <MyEnrolledCourse>[];
    for (final course in courses) {
      for (final batch in course.batches) {
        if (batch.userEnrolled) {
          result.add(MyEnrolledCourse(course: course, batch: batch));
        }
      }
    }
    return result;
  }

  @override
  Future<CourseEnrollmentRecord> enroll({
    required String batchId,
    bool isTrial = false,
    String studentName = '',
    String contactPhone = '',
    DateTime? preferredStart,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      Map<String, dynamic> row;
      try {
        final raw = await _client.rpc<dynamic>(
          'enroll_in_course_details',
          params: {
            'p_batch_id': batchId,
            'p_user_id': userId,
            'p_is_trial': isTrial,
            'p_student_name': studentName,
            'p_contact_phone': contactPhone,
            'p_preferred_start': preferredStart?.toIso8601String(),
          },
        );
        row = Map<String, dynamic>.from(raw as Map);
      } on PostgrestException catch (e) {
        if (!_isMissingRelation(e) && e.code != 'PGRST202') rethrow;
        final raw = await _client.rpc<dynamic>(
          'enroll_in_course',
          params: {'p_batch_id': batchId, 'p_user_id': userId},
        );
        row = raw is Map
            ? Map<String, dynamic>.from(raw)
            : {'id': '', 'batch_id': batchId, 'status': 'enrolled'};
      }
      return CourseEnrollmentRecord.fromJson(row);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('batch full')) {
        throw const app_errors.BusinessException(
          'This batch is full.',
          code: 'batch_full',
        );
      }
      if (message.contains('batch not available')) {
        throw const app_errors.BusinessException(
          'This batch is no longer accepting enrollments.',
          code: 'batch_unavailable',
        );
      }
      if (message.contains('already enrolled') ||
          message.contains('duplicate')) {
        throw const app_errors.BusinessException(
          'You are already enrolled in this batch.',
          code: 'duplicate_enrollment',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> drop({required String batchId}) async {
    final userId = _userId;
    if (userId == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      await _client.rpc<dynamic>(
        'drop_course_enrollment',
        params: {'p_batch_id': batchId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> registerForDemo({
    required String courseId,
    required String studentName,
    required String mobile,
    String email = '',
    String preferredBatch = '',
    String note = '',
  }) async {
    final userId = _userId;
    try {
      await _client.from('course_demo_registrations').insert({
        'course_id': courseId,
        'user_id': userId,
        'student_name': studentName,
        'mobile': mobile,
        'email': email,
        'preferred_batch': preferredBatch,
        'note': note,
        'status': 'pending',
      });
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) {
        throw const app_errors.BusinessException(
          'Demo registration is not available yet.',
          code: 'demo_unavailable',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<CourseFeedback>> courseFeedback(String courseId) async {
    try {
      final rows = await _client
          .from('course_feedback')
          .select('*')
          .eq('course_id', courseId)
          .order('created_at', ascending: false);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(CourseFeedback.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) return const [];
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> submitFeedback({
    required String courseId,
    required int rating,
    String comment = '',
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw const app_errors.AuthException('You must be signed in.');
    }
    try {
      await _client.from('course_feedback').insert({
        'course_id': courseId,
        'user_id': userId,
        'rating': rating,
        'comment': comment,
      });
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) {
        throw const app_errors.BusinessException(
          'Feedback is not available yet.',
          code: 'feedback_unavailable',
        );
      }
      final message = e.message.toLowerCase();
      if (e.code == '42501' || message.contains('not enrolled')) {
        throw const app_errors.BusinessException(
          'Only enrolled learners can submit feedback.',
          code: 'not_enrolled',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  Future<List<String>> _myInstituteIds() async {
    final userId = _userId;
    if (userId == null) return const [];
    final orgs = await _client
        .from('organizations')
        .select('id')
        .eq('owner_user_id', userId);
    final orgIds = orgs
        .whereType<Map<String, dynamic>>()
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    if (orgIds.isEmpty) return const [];
    final rows = await _client
        .from('institutes')
        .select('id')
        .inFilter('org_id', orgIds);
    return rows
        .whereType<Map<String, dynamic>>()
        .map((r) => (r['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  @override
  Future<List<Course>> ownerCourses() async {
    final instituteIds = await _myInstituteIds();
    if (instituteIds.isEmpty) return const [];
    try {
      final rows = await _selectCourses(
        (select) => _client
            .from('courses')
            .select(select)
            .inFilter('institute_id', instituteIds)
            .order('created_at', ascending: false),
      );
      return rows.map(Course.fromJson).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<Institute>> ownerInstitutes() async {
    final instituteIds = await _myInstituteIds();
    if (instituteIds.isEmpty) return const [];
    try {
      final rows = await _client
          .from('institutes')
          .select('*')
          .inFilter('id', instituteIds)
          .order('name', ascending: true);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Institute.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<String> saveCourse({
    String? courseId,
    required String instituteId,
    required String title,
    required String description,
    required CourseMode mode,
    required int durationWeeks,
    required double feeAmount,
    String instructorName = '',
    String coverImage = '',
    String categoryId = '',
    double discountAmount = 0,
    List<CourseDemoMethod> demoMethods = const [],
    String demoVideoUrl = '',
    String demoThumbnailUrl = '',
    String brochureUrl = '',
    String externalRegistrationUrl = '',
    String contactPhone = '',
    List<String> syllabusPoints = const [],
    bool publish = false,
  }) async {
    final full = <String, dynamic>{
      if (courseId != null) 'id': courseId,
      'institute_id': instituteId,
      'title': title,
      'description': description,
      'mode': mode.dbValue,
      'duration_weeks': durationWeeks,
      'fee_amount': feeAmount,
      'instructor_name': instructorName,
      'cover_image': coverImage,
      'status': publish ? 'published' : 'draft',
      'category_id': categoryId,
      'discount_amount': discountAmount,
      'demo_methods': demoMethods.map((m) => m.dbValue).toList(),
      'demo_video_url': demoVideoUrl,
      'demo_thumbnail_url': demoThumbnailUrl,
      'brochure_url': brochureUrl,
      'external_registration_url': externalRegistrationUrl,
      'contact_phone': contactPhone,
      'syllabus_points': syllabusPoints,
    };
    final base = <String, dynamic>{
      if (courseId != null) 'id': courseId,
      'institute_id': instituteId,
      'title': title,
      'description': description,
      'mode': mode.dbValue,
      'duration_weeks': durationWeeks,
      'fee_amount': feeAmount,
      'instructor_name': instructorName,
      'cover_image': coverImage,
      'status': publish ? 'published' : 'draft',
    };
    try {
      final row =
          await _client.from('courses').upsert(full).select('id').single();
      return (row['id'] ?? '').toString();
    } on PostgrestException catch (e) {
      if (!_isMissingRelation(e)) throw app_errors.mapError(e);
      final row =
          await _client.from('courses').upsert(base).select('id').single();
      return (row['id'] ?? '').toString();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> saveBatch({
    String? batchId,
    required String courseId,
    required String label,
    required DateTime startsOn,
    required int capacity,
    bool isActive = true,
    String timing = '',
    DateTime? endsOn,
    double feeAmount = 0,
    CourseMode? mode,
    bool waitlistEnabled = false,
    bool admissionsOpen = true,
    String subject = '',
    String categorySlug = '',
  }) async {
    final payload = <String, dynamic>{
      if (batchId != null) 'id': batchId,
      'course_id': courseId,
      'label': label,
      'starts_on': startsOn.toIso8601String(),
      'capacity': capacity,
      'is_active': isActive,
    };
    final extended = {
      ...payload,
      'timing': timing,
      'ends_on': endsOn?.toIso8601String(),
      'fee_amount': feeAmount,
      if (mode != null) 'mode': mode.dbValue,
      'waitlist_enabled': waitlistEnabled,
      'admissions_open': admissionsOpen,
      'subject': subject,
      'category_slug': categorySlug,
    };
    try {
      await _client.from('course_batches').upsert(extended);
    } on PostgrestException catch (e) {
      if (!_isMissingRelation(e)) throw app_errors.mapError(e);
      await _client.from('course_batches').upsert(payload);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<CourseDemoRegistration>> ownerAdmissions() async {
    try {
      final rows = await _client
          .from('course_demo_registrations')
          .select()
          .order('created_at', ascending: false);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(CourseDemoRegistration.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) return const [];
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> setAdmissionStatus({
    required String registrationId,
    required String status,
  }) async {
    try {
      await _client
          .from('course_demo_registrations')
          .update({'status': status}).eq('id', registrationId);
    } on PostgrestException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> updateInstitute({
    required String instituteId,
    String? address,
    String? city,
    String? phone,
    String? timings,
    List<String>? amenities,
  }) async {
    final payload = <String, dynamic>{
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (phone != null) 'phone': phone,
      if (timings != null) 'timings': timings,
      if (amenities != null) 'amenities': amenities,
    };
    if (payload.isEmpty) return;
    try {
      await _client.from('institutes').update(payload).eq('id', instituteId);
    } on PostgrestException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> addFaculty({
    required String courseId,
    required String name,
    String role = '',
    String bio = '',
  }) async {
    try {
      await _client.from('course_faculty').insert({
        'course_id': courseId,
        'name': name,
        'role': role,
        'bio': bio,
      });
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) {
        throw const app_errors.BusinessException(
          'Faculty profiles are not available yet.',
          code: 'faculty_unavailable',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> addFaq({
    required String courseId,
    required String question,
    required String answer,
    int displayOrder = 0,
  }) async {
    try {
      await _client.from('course_faqs').insert({
        'course_id': courseId,
        'question': question,
        'answer': answer,
        'display_order': displayOrder,
      });
    } on PostgrestException catch (e) {
      if (_isMissingRelation(e)) {
        throw const app_errors.BusinessException(
          'FAQs are not available yet.',
          code: 'faq_unavailable',
        );
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
