import '../domain/course.dart';

/// Contract for the courses feature.
abstract interface class CourseRepository {
  /// Published courses, newest first, with their institute.
  Future<List<Course>> publishedCourses();

  /// A single course with its batches and institute.
  Future<Course> courseDetail(String courseId);

  /// Enrolls the current user into a batch (atomic, capacity-safe).
  Future<CourseEnrollmentRecord> enroll({
    required String batchId,
    bool isTrial = false,
    String studentName = '',
    String contactPhone = '',
    DateTime? preferredStart,
  });

  /// Drops my enrollment from a batch, freeing a seat.
  Future<void> drop({required String batchId});

  /// Owner-visible trial and admission requests for their institutes.
  Future<List<CourseDemoRegistration>> ownerAdmissions();

  /// Approve or reject a demo/trial admission (`pending` → contacted/cancelled).
  Future<void> setAdmissionStatus({
    required String registrationId,
    required String status,
  });

  /// Updates institute profile fields the owner is allowed to write.
  Future<void> updateInstitute({
    required String instituteId,
    String? address,
    String? city,
    String? phone,
    String? timings,
    List<String>? amenities,
  });

  /// All institutes visible to the current role, name-ordered.
  Future<List<Institute>> institutes();

  /// A single institute profile.
  Future<Institute> instituteDetail(String instituteId);

  /// Published courses offered by one institute.
  Future<List<Course>> coursesForInstitute(String instituteId);

  /// The signed-in learner's active enrollments joined to course and batch.
  Future<List<MyEnrolledCourse>> myEnrolledCourses();

  /// Records an internal demo-class request for a course.
  Future<void> registerForDemo({
    required String courseId,
    required String studentName,
    required String mobile,
    String email,
    String preferredBatch,
    String note,
  });

  /// Published feedback for a course, newest first.
  Future<List<CourseFeedback>> courseFeedback(String courseId);

  /// Submits feedback; only valid for an enrolled learner.
  Future<void> submitFeedback({
    required String courseId,
    required int rating,
    String comment,
  });

  /// Courses owned by the signed-in owner's institute(s), any status.
  Future<List<Course>> ownerCourses();

  /// Institutes the signed-in owner may manage (their own organizations).
  Future<List<Institute>> ownerInstitutes();

  /// Creates or updates a course. [publish] flips status to published;
  /// otherwise the course stays a draft.
  Future<String> saveCourse({
    String? courseId,
    required String instituteId,
    required String title,
    required String description,
    required CourseMode mode,
    required int durationWeeks,
    required double feeAmount,
    String instructorName,
    String coverImage,
    String categoryId,
    double discountAmount,
    List<CourseDemoMethod> demoMethods,
    String demoVideoUrl,
    String demoThumbnailUrl,
    String brochureUrl,
    String externalRegistrationUrl,
    String contactPhone,
    List<String> syllabusPoints,
    bool publish,
  });

  /// Adds or replaces a batch on a course.
  Future<void> saveBatch({
    String? batchId,
    required String courseId,
    required String label,
    required DateTime startsOn,
    required int capacity,
    bool isActive,
    String timing = '',
    DateTime? endsOn,
    double feeAmount = 0,
    CourseMode? mode,
    bool waitlistEnabled = false,
    bool admissionsOpen = true,
    String subject = '',
    String categorySlug = '',
  });

  /// Adds a faculty profile to a course.
  Future<void> addFaculty({
    required String courseId,
    required String name,
    String role,
    String bio,
  });

  /// Adds a FAQ entry to a course.
  Future<void> addFaq({
    required String courseId,
    required String question,
    required String answer,
    int displayOrder,
  });
}
