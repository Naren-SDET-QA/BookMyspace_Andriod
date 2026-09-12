import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';
import '../infrastructure/supabase_course_repository.dart';

/// Courses repository instance.
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseCourseRepository(client);
});

/// Published courses. Watches auth so enrollment flags refresh after login.
final publishedCoursesProvider = FutureProvider<List<Course>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(courseRepositoryProvider).publishedCourses();
});

final coursesProvider = publishedCoursesProvider;

/// A single course with batches and the current user's enrollment flags.
final courseDetailProvider =
    FutureProvider.autoDispose.family<Course, String>((ref, courseId) {
  ref.watch(currentUserProvider);
  return ref.watch(courseRepositoryProvider).courseDetail(courseId);
});

/// User-action helper. Do not watch from build().
class CourseEnrollmentController {
  CourseEnrollmentController(this._ref);

  final Ref _ref;

  Future<void> enroll({
    required String courseId,
    required String batchId,
  }) async {
    await _ref.read(courseRepositoryProvider).enroll(batchId: batchId);
    _ref.invalidate(publishedCoursesProvider);
    _ref.invalidate(courseDetailProvider(courseId));
  }

  Future<void> drop({
    required String courseId,
    required String batchId,
  }) async {
    await _ref.read(courseRepositoryProvider).drop(batchId: batchId);
    _ref.invalidate(publishedCoursesProvider);
    _ref.invalidate(courseDetailProvider(courseId));
  }
}

final courseEnrollmentControllerProvider =
    Provider<CourseEnrollmentController>((ref) {
  return CourseEnrollmentController(ref);
});
