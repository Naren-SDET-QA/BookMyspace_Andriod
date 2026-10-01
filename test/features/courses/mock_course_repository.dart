import 'package:bookmyspace/features/cms/domain/configurable_form.dart';
import 'package:bookmyspace/features/cms/domain/target_modules.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/domain/course_repository.dart';

/// In-memory course repository for tests and widget tests.
class MockCourseRepository implements CourseRepository {
  MockCourseRepository();

  List<Course> courses = const [];
  List<Institute> instituteList = const [];
  List<CourseFaculty> facultyList = const [];
  List<CourseFeedback> feedbackList = const [];
  List<CourseDemoRegistration> admissions = const [];
  List<InstituteBranch> branchList = const [];
  Map<String, dynamic> lastFormAnswers = const {};
  int _idSeq = 0;

  bool failList = false;
  bool failDetail = false;
  bool failEnroll = false;
  bool failDrop = false;
  bool failInstitutes = false;
  bool failInstituteDetail = false;
  bool failInstituteCourses = false;
  bool failDemo = false;
  bool failFeedback = false;
  bool failSaveCourse = false;

  String? lastEnrollBatchId;
  String? lastDropBatchId;

  /// Records every mutating call for assertions.
  final List<String> calls = [];

  static Course sampleCourse({
    String id = 'c1',
    String title = 'Flutter App Development Bootcamp',
    int batchCount = 2,
  }) {
    return Course(
      id: id,
      instituteId: 'i1',
      title: title,
      description: 'Build and ship production Flutter apps in 8 weeks.',
      mode: CourseMode.offline,
      durationWeeks: 8,
      feeAmount: 29999,
      instructorName: 'Anand Kumar',
      coverImage: 'https://example.com/cover.jpg',
      status: 'published',
      instituteName: 'Nexus Learning Institute',
      instituteVerified: true,
      batches: List.generate(batchCount, (i) {
        return CourseBatch(
          id: 'b$i',
          courseId: id,
          label: i == 0 ? 'Weekday Batch A' : 'Weekend Batch B',
          startsOn: DateTime.now().add(Duration(days: 7 * (i + 1))),
          capacity: 25,
          enrolledCount: i == 0 ? 3 : 20,
          isActive: true,
        );
      }),
    );
  }

  static Institute sampleInstitute({String id = 'i1'}) {
    return Institute(
      id: id,
      orgId: 'o1',
      name: 'Nexus Learning Institute',
      description: 'Premium software training.',
      logoImage: 'https://example.com/logo.png',
      isVerified: true,
      type: InstituteType.privateInstitute,
      city: 'Hyderabad',
      address: 'Madhapur, Hyderabad',
      phone: '+919000000000',
    );
  }

  @override
  Future<List<Course>> publishedCourses() async {
    if (failList) throw Exception('list failed');
    return courses.where((c) => c.isPublished).toList();
  }

  @override
  Future<Course> courseDetail(String courseId) async {
    if (failDetail) throw Exception('detail failed');
    return courses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => sampleCourse(),
    );
  }

  @override
  Future<CourseEnrollmentRecord> enroll({
    required String batchId,
    bool isTrial = false,
    String studentName = '',
    String contactPhone = '',
    DateTime? preferredStart,
    Map<String, dynamic> formAnswers = const {},
  }) async {
    if (failEnroll) throw Exception('enroll failed');
    lastEnrollBatchId = batchId;
    lastFormAnswers = formAnswers;
    calls.add('enroll:$batchId');
    courses = courses
        .map(
          (course) => course.copyWith(
            batches: course.batches
                .map(
                  (batch) => batch.id == batchId
                      ? batch.copyWith(
                          userEnrolled: true,
                          enrolledCount: isTrial
                              ? batch.enrolledCount
                              : batch.enrolledCount + 1,
                        )
                      : batch,
                )
                .toList(),
          ),
        )
        .toList();
    return CourseEnrollmentRecord(
      id: 'enr-${++_idSeq}',
      batchId: batchId,
      status: isTrial ? 'trial' : 'enrolled',
      isTrial: isTrial,
      admissionCode: 'ADM-TEST$_idSeq',
      studentName: studentName,
      contactPhone: contactPhone,
    );
  }

  @override
  Future<void> drop({required String batchId}) async {
    if (failDrop) throw Exception('drop failed');
    lastDropBatchId = batchId;
    calls.add('drop:$batchId');
    courses = courses
        .map(
          (course) => course.copyWith(
            batches: course.batches
                .map(
                  (batch) => batch.id == batchId
                      ? batch.copyWith(
                          userEnrolled: false,
                          enrolledCount: batch.enrolledCount > 0
                              ? batch.enrolledCount - 1
                              : 0,
                        )
                      : batch,
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Future<List<Institute>> institutes() async {
    if (failInstitutes) throw Exception('institutes failed');
    return instituteList;
  }

  @override
  Future<Institute> instituteDetail(String instituteId) async {
    if (failInstituteDetail) throw Exception('institute detail failed');
    return instituteList.firstWhere(
      (i) => i.id == instituteId,
      orElse: () => sampleInstitute(id: instituteId),
    );
  }

  @override
  Future<List<Course>> coursesForInstitute(String instituteId) async {
    if (failInstituteCourses) throw Exception('institute courses failed');
    return courses
        .where((c) => c.instituteId == instituteId && c.isPublished)
        .toList();
  }

  @override
  Future<List<MyEnrolledCourse>> myEnrolledCourses() async {
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
  Future<void> registerForDemo({
    required String courseId,
    required String studentName,
    required String mobile,
    String email = '',
    String preferredBatch = '',
    String note = '',
  }) async {
    if (failDemo) throw Exception('demo failed');
    calls.add('demo:$courseId:$studentName:$mobile');
  }

  @override
  Future<List<CourseFeedback>> courseFeedback(String courseId) async {
    return feedbackList.where((f) => f.courseId == courseId).toList();
  }

  @override
  Future<void> submitFeedback({
    required String courseId,
    required int rating,
    String comment = '',
  }) async {
    if (failFeedback) throw Exception('feedback failed');
    calls.add('feedback:$courseId:$rating');
    feedbackList = [
      CourseFeedback(
        id: 'f${_idSeq++}',
        courseId: courseId,
        rating: rating,
        comment: comment,
        authorName: 'You',
      ),
      ...feedbackList,
    ];
  }

  @override
  Future<List<Course>> ownerCourses() async {
    return courses;
  }

  @override
  Future<List<Institute>> ownerInstitutes() async {
    return instituteList;
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
    if (failSaveCourse) throw Exception('save course failed');
    final id = courseId ?? 'c${_idSeq++}';
    calls.add('saveCourse:$id:${publish ? "published" : "draft"}');
    final saved = Course(
      id: id,
      instituteId: instituteId,
      title: title,
      description: description,
      mode: mode,
      durationWeeks: durationWeeks,
      feeAmount: feeAmount,
      instructorName: instructorName,
      coverImage: coverImage,
      status: publish ? 'published' : 'draft',
      categoryId: categoryId,
      discountAmount: discountAmount,
      demoMethods: demoMethods,
      demoVideoUrl: demoVideoUrl,
      demoThumbnailUrl: demoThumbnailUrl,
      brochureUrl: brochureUrl,
      externalRegistrationUrl: externalRegistrationUrl,
      contactPhone: contactPhone,
      syllabusPoints: syllabusPoints,
    );
    final index = courses.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final next = [...courses];
      next[index] = saved;
      courses = next;
    } else {
      courses = [...courses, saved];
    }
    return id;
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
    calls.add('saveBatch:$courseId:$label');
    final id = batchId ?? 'nb${_idSeq++}';
    final batch = CourseBatch(
      id: id,
      courseId: courseId,
      label: label,
      startsOn: startsOn,
      capacity: capacity,
      enrolledCount: 0,
      isActive: isActive,
      timing: timing,
      endsOn: endsOn,
      feeAmount: feeAmount,
      mode: mode,
      waitlistEnabled: waitlistEnabled,
      admissionsOpen: admissionsOpen,
      subject: subject,
      categorySlug: categorySlug,
    );
    courses = courses.map((course) {
      if (course.id != courseId) return course;
      final idx = course.batches.indexWhere((b) => b.id == id);
      final batches = [...course.batches];
      if (idx >= 0) {
        batches[idx] = batch;
      } else {
        batches.add(batch);
      }
      return course.copyWith(batches: batches);
    }).toList();
  }

  @override
  Future<List<CourseDemoRegistration>> ownerAdmissions() async => admissions;

  @override
  Future<void> setAdmissionStatus({
    required String registrationId,
    required String status,
  }) async {
    calls.add('admission:$registrationId:$status');
    admissions = admissions
        .map(
          (item) => item.id == registrationId
              ? CourseDemoRegistration(
                  id: item.id,
                  courseId: item.courseId,
                  studentName: item.studentName,
                  mobile: item.mobile,
                  email: item.email,
                  preferredBatch: item.preferredBatch,
                  note: item.note,
                  status: status,
                )
              : item,
        )
        .toList();
  }

  @override
  Future<void> updateInstitute({
    required String instituteId,
    String? address,
    String? city,
    String? phone,
    String? timings,
    List<String>? amenities,
    TargetModuleConfig? modules,
    ConfigurableFormSchema? registrationForm,
    Map<String, dynamic>? profile,
  }) async {
    calls.add('updateInstitute:$instituteId');
    instituteList = instituteList
        .map(
          (item) => item.id == instituteId
              ? item.copyWith(
                  address: address,
                  city: city,
                  phone: phone,
                  timingsText: timings,
                  amenities: amenities,
                  modules: modules,
                  registrationForm: registrationForm,
                  profile: profile,
                )
              : item,
        )
        .toList();
  }

  @override
  Future<List<InstituteBranch>> branches(String instituteId) async {
    return branchList.where((b) => b.instituteId == instituteId).toList();
  }

  @override
  Future<void> saveBranch(InstituteBranch branch) async {
    calls.add('saveBranch:${branch.instituteId}');
    final id = branch.id.isEmpty ? 'br${++_idSeq}' : branch.id;
    final stored = InstituteBranch(
      id: id,
      instituteId: branch.instituteId,
      name: branch.name,
      address: branch.address,
      city: branch.city,
      isPrimary: branch.isPrimary,
      isActive: branch.isActive,
      isOnlineOnly: branch.isOnlineOnly,
    );
    branchList = [
      ...branchList.where((item) => item.id != id),
      stored,
    ];
  }

  @override
  Future<void> deleteBranch(String branchId) async {
    calls.add('deleteBranch:$branchId');
    branchList = branchList.where((item) => item.id != branchId).toList();
  }

  @override
  Future<void> addFaculty({
    required String courseId,
    required String name,
    String role = '',
    String bio = '',
    String instituteId = '',
    String photoUrl = '',
    String designation = '',
    String qualification = '',
    String specialization = '',
    String experienceText = '',
    String demoUrl = '',
  }) async {
    calls.add('addFaculty:$courseId:$name');
    facultyList = [
      ...facultyList,
      CourseFaculty(
        id: 'fac${_idSeq++}',
        courseId: courseId,
        instituteId: instituteId,
        name: name,
        role: role,
        bio: bio,
        photoUrl: photoUrl,
        designation: designation,
        qualification: qualification,
        specialization: specialization,
        experienceText: experienceText,
        demoUrl: demoUrl,
      ),
    ];
    courses = courses.map((course) {
      if (course.id != courseId) return course;
      return course.copyWith(
        faculty: [
          ...course.faculty,
          CourseFaculty(
            id: 'fac',
            courseId: courseId,
            name: name,
            role: role,
            bio: bio,
          ),
        ],
      );
    }).toList();
  }

  @override
  Future<void> addFaq({
    required String courseId,
    required String question,
    required String answer,
    int displayOrder = 0,
  }) async {
    calls.add('addFaq:$courseId:$question');
    final faq = CourseFaq(
      id: 'faq${_idSeq++}',
      courseId: courseId,
      question: question,
      answer: answer,
      displayOrder: displayOrder,
    );
    courses = courses.map((course) {
      if (course.id != courseId) return course;
      return course.copyWith(faqs: [...course.faqs, faq]);
    }).toList();
  }
}
