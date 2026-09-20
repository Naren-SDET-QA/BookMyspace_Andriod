import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_service.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';
import '../infrastructure/supabase_course_repository.dart';

/// Courses repository instance.
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseCourseRepository(client);
});

/// Shared storage helper for education demo videos, brochures and thumbnails.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseProvider));
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

/// All institutes, name-ordered.
final institutesProvider = FutureProvider<List<Institute>>((ref) {
  return ref.watch(courseRepositoryProvider).institutes();
});

/// A single institute profile.
final instituteDetailProvider =
    FutureProvider.autoDispose.family<Institute, String>((ref, instituteId) {
  return ref.watch(courseRepositoryProvider).instituteDetail(instituteId);
});

/// Published courses offered by one institute.
final instituteCoursesProvider =
    FutureProvider.autoDispose.family<List<Course>, String>((ref, instituteId) {
  return ref.watch(courseRepositoryProvider).coursesForInstitute(instituteId);
});

/// The signed-in learner's active enrollments. Watches auth so it refreshes
/// after login and clears when signed out.
final myCoursesProvider = FutureProvider<List<MyEnrolledCourse>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(courseRepositoryProvider).myEnrolledCourses();
});

/// Published feedback for a course, newest first.
final courseFeedbackProvider = FutureProvider.autoDispose
    .family<List<CourseFeedback>, String>((ref, courseId) {
  return ref.watch(courseRepositoryProvider).courseFeedback(courseId);
});

/// Courses owned by the signed-in owner's institute(s), any status.
final ownerCoursesProvider = FutureProvider<List<Course>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(courseRepositoryProvider).ownerCourses();
});

/// Institutes the signed-in owner may manage, for the course editor picker.
final ownerInstitutesProvider = FutureProvider<List<Institute>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(courseRepositoryProvider).ownerInstitutes();
});

/// Whether the signed-in learner is enrolled in a given course, derived from
/// My Courses so the course detail screen can gate feedback and attendance.
final isEnrolledInCourseProvider =
    Provider.family<bool, String>((ref, courseId) {
  final mine = ref.watch(myCoursesProvider).valueOrNull ?? const [];
  return mine.any((e) => e.course.id == courseId);
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
    _ref.invalidate(myCoursesProvider);
    _ref.invalidate(instituteCoursesProvider);
  }

  Future<void> drop({
    required String courseId,
    required String batchId,
  }) async {
    await _ref.read(courseRepositoryProvider).drop(batchId: batchId);
    _ref.invalidate(publishedCoursesProvider);
    _ref.invalidate(courseDetailProvider(courseId));
    _ref.invalidate(myCoursesProvider);
    _ref.invalidate(instituteCoursesProvider);
  }
}

final courseEnrollmentControllerProvider =
    Provider<CourseEnrollmentController>((ref) {
  return CourseEnrollmentController(ref);
});

/// Handles internal demo-class registration and course feedback. Do not watch
/// from build().
class CourseInteractionController {
  CourseInteractionController(this._ref);

  final Ref _ref;

  Future<void> registerForDemo({
    required String courseId,
    required String studentName,
    required String mobile,
    String email = '',
    String preferredBatch = '',
    String note = '',
  }) async {
    await _ref.read(courseRepositoryProvider).registerForDemo(
          courseId: courseId,
          studentName: studentName,
          mobile: mobile,
          email: email,
          preferredBatch: preferredBatch,
          note: note,
        );
  }

  Future<void> submitFeedback({
    required String courseId,
    required int rating,
    String comment = '',
  }) async {
    await _ref.read(courseRepositoryProvider).submitFeedback(
          courseId: courseId,
          rating: rating,
          comment: comment,
        );
    _ref.invalidate(courseFeedbackProvider(courseId));
  }
}

final courseInteractionControllerProvider =
    Provider<CourseInteractionController>((ref) {
  return CourseInteractionController(ref);
});

/// Owner course CRUD: create/edit courses, batches and faculty. Do not watch
/// from build().
class OwnerCourseController {
  OwnerCourseController(this._ref);

  final Ref _ref;

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
    final id = await _ref.read(courseRepositoryProvider).saveCourse(
          courseId: courseId,
          instituteId: instituteId,
          title: title,
          description: description,
          mode: mode,
          durationWeeks: durationWeeks,
          feeAmount: feeAmount,
          instructorName: instructorName,
          coverImage: coverImage,
          categoryId: categoryId,
          discountAmount: discountAmount,
          demoMethods: demoMethods,
          demoVideoUrl: demoVideoUrl,
          demoThumbnailUrl: demoThumbnailUrl,
          brochureUrl: brochureUrl,
          externalRegistrationUrl: externalRegistrationUrl,
          contactPhone: contactPhone,
          syllabusPoints: syllabusPoints,
          publish: publish,
        );
    _ref.invalidate(ownerCoursesProvider);
    _ref.invalidate(publishedCoursesProvider);
    _ref.invalidate(courseDetailProvider(id));
    _ref.invalidate(instituteCoursesProvider(instituteId));
    return id;
  }

  Future<void> saveBatch({
    String? batchId,
    required String courseId,
    required String label,
    required DateTime startsOn,
    required int capacity,
    bool isActive = true,
  }) async {
    await _ref.read(courseRepositoryProvider).saveBatch(
          batchId: batchId,
          courseId: courseId,
          label: label,
          startsOn: startsOn,
          capacity: capacity,
          isActive: isActive,
        );
    _ref.invalidate(courseDetailProvider(courseId));
    _ref.invalidate(ownerCoursesProvider);
  }

  Future<void> addFaculty({
    required String courseId,
    required String name,
    String role = '',
    String bio = '',
  }) async {
    await _ref.read(courseRepositoryProvider).addFaculty(
          courseId: courseId,
          name: name,
          role: role,
          bio: bio,
        );
    _ref.invalidate(courseDetailProvider(courseId));
    _ref.invalidate(ownerCoursesProvider);
  }

  Future<void> addFaq({
    required String courseId,
    required String question,
    required String answer,
    int displayOrder = 0,
  }) async {
    await _ref.read(courseRepositoryProvider).addFaq(
          courseId: courseId,
          question: question,
          answer: answer,
          displayOrder: displayOrder,
        );
    _ref.invalidate(courseDetailProvider(courseId));
    _ref.invalidate(ownerCoursesProvider);
  }
}

final ownerCourseControllerProvider = Provider<OwnerCourseController>((ref) {
  return OwnerCourseController(ref);
});
