/// Course delivery mode (`course_mode` enum).
enum CourseMode {
  online,
  offline,
  hybrid;

  static CourseMode fromDb(String value) => switch (value) {
        'online' => CourseMode.online,
        'offline' => CourseMode.offline,
        'hybrid' => CourseMode.hybrid,
        _ => CourseMode.offline,
      };

  String get dbValue => name;
}

/// Institute ownership / government classification (`institutes.institute_type`).
enum InstituteType {
  privateInstitute,
  stateGovernment,
  centralGovernment,
  university,
  ngo,
  other;

  static InstituteType fromDb(String value) => switch (value) {
        'private' => InstituteType.privateInstitute,
        'state_government' => InstituteType.stateGovernment,
        'central_government' => InstituteType.centralGovernment,
        'university' => InstituteType.university,
        'ngo' => InstituteType.ngo,
        _ => InstituteType.other,
      };

  String get dbValue => switch (this) {
        InstituteType.privateInstitute => 'private',
        InstituteType.stateGovernment => 'state_government',
        InstituteType.centralGovernment => 'central_government',
        InstituteType.university => 'university',
        InstituteType.ngo => 'ngo',
        InstituteType.other => 'other',
      };

  String get label => switch (this) {
        InstituteType.privateInstitute => 'Private',
        InstituteType.stateGovernment => 'State Government',
        InstituteType.centralGovernment => 'Central Government',
        InstituteType.university => 'University',
        InstituteType.ngo => 'NGO',
        InstituteType.other => 'Other',
      };
}

/// An education institute offering courses (`institutes`).
///
/// Profile columns (type, location, contact, mode, timings, images) are
/// additive; older schemas omit them and [fromJson] defaults them safely so
/// the app degrades gracefully before the education migration is applied.
class Institute {
  const Institute({
    required this.id,
    required this.orgId,
    required this.name,
    this.description = '',
    this.logoImage = '',
    this.isVerified = false,
    this.type = InstituteType.other,
    this.categoryId = '',
    this.address = '',
    this.city = '',
    this.latitude,
    this.longitude,
    this.phone = '',
    this.email = '',
    this.whatsapp = '',
    this.website = '',
    this.mode = CourseMode.offline,
    this.timingsText = '',
    this.images = const [],
    this.amenities = const [],
  });

  final String id;
  final String orgId;
  final String name;
  final String description;
  final String logoImage;
  final bool isVerified;
  final InstituteType type;
  final String categoryId;
  final String address;
  final String city;
  final double? latitude;
  final double? longitude;
  final String phone;
  final String email;
  final String whatsapp;
  final String website;
  final CourseMode mode;
  final String timingsText;
  final List<String> images;
  final List<String> amenities;

  bool get hasContact =>
      phone.isNotEmpty || email.isNotEmpty || whatsapp.isNotEmpty;

  bool get hasLocation => address.isNotEmpty || city.isNotEmpty;

  factory Institute.fromJson(Map<String, dynamic> json) => Institute(
        id: json['id'] as String? ?? '',
        orgId: json['org_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        logoImage: json['logo_image'] as String? ?? '',
        isVerified: json['is_verified'] as bool? ?? false,
        type: InstituteType.fromDb(json['institute_type'] as String? ?? ''),
        categoryId: json['category_id'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        website: json['website'] as String? ?? '',
        mode: CourseMode.fromDb(json['mode'] as String? ?? ''),
        timingsText: json['timings'] as String? ?? '',
        images:
            (json['images'] as List? ?? const []).whereType<String>().toList(),
        amenities: (json['amenities'] as List? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(),
      );
}

/// How a learner can register for / preview a demo (`courses.demo_methods`).
enum CourseDemoMethod {
  internalForm,
  externalLink,
  phoneWhatsApp,
  uploadedVideo,
  uploadedBrochure,
  scheduledLive,
  recordedPreview,
  noDemo;

  static CourseDemoMethod? fromDb(String value) => switch (value) {
        'internal_form' => CourseDemoMethod.internalForm,
        'external_link' => CourseDemoMethod.externalLink,
        'phone_whatsapp' => CourseDemoMethod.phoneWhatsApp,
        'uploaded_video' => CourseDemoMethod.uploadedVideo,
        'uploaded_brochure' => CourseDemoMethod.uploadedBrochure,
        'scheduled_live' => CourseDemoMethod.scheduledLive,
        'recorded_preview' => CourseDemoMethod.recordedPreview,
        'no_demo' => CourseDemoMethod.noDemo,
        _ => null,
      };

  String get dbValue => switch (this) {
        CourseDemoMethod.internalForm => 'internal_form',
        CourseDemoMethod.externalLink => 'external_link',
        CourseDemoMethod.phoneWhatsApp => 'phone_whatsapp',
        CourseDemoMethod.uploadedVideo => 'uploaded_video',
        CourseDemoMethod.uploadedBrochure => 'uploaded_brochure',
        CourseDemoMethod.scheduledLive => 'scheduled_live',
        CourseDemoMethod.recordedPreview => 'recorded_preview',
        CourseDemoMethod.noDemo => 'no_demo',
      };

  String get label => switch (this) {
        CourseDemoMethod.internalForm => 'Register for Demo',
        CourseDemoMethod.externalLink => 'Open Registration Link',
        CourseDemoMethod.phoneWhatsApp => 'Contact Institute',
        CourseDemoMethod.uploadedVideo => 'Watch Demo',
        CourseDemoMethod.uploadedBrochure => 'Download Brochure',
        CourseDemoMethod.scheduledLive => 'Join Live Demo',
        CourseDemoMethod.recordedPreview => 'Watch Recorded Preview',
        CourseDemoMethod.noDemo => 'No demo available',
      };
}

/// A published course (`courses`).
class Course {
  const Course({
    required this.id,
    required this.instituteId,
    required this.title,
    required this.description,
    required this.mode,
    required this.durationWeeks,
    required this.feeAmount,
    required this.status,
    this.venueId = '',
    this.instructorName = '',
    this.coverImage = '',
    this.instituteName = '',
    this.instituteVerified = false,
    this.instituteCity = '',
    this.batches = const [],
    this.categoryId = '',
    this.discountAmount = 0,
    this.demoMethods = const [],
    this.demoVideoUrl = '',
    this.demoThumbnailUrl = '',
    this.brochureUrl = '',
    this.externalRegistrationUrl = '',
    this.contactPhone = '',
    this.faculty = const [],
    this.syllabusPoints = const [],
    this.faqs = const [],
  });

  final String id;
  final String instituteId;
  final String title;
  final String description;
  final CourseMode mode;
  final String venueId;
  final int durationWeeks;
  final double feeAmount;
  final String instructorName;
  final String coverImage;
  final String status;
  final String instituteName;
  final bool instituteVerified;
  final String instituteCity;
  final List<CourseBatch> batches;
  final String categoryId;
  final double discountAmount;
  final List<CourseDemoMethod> demoMethods;
  final String demoVideoUrl;
  final String demoThumbnailUrl;
  final String brochureUrl;
  final String externalRegistrationUrl;
  final String contactPhone;
  final List<CourseFaculty> faculty;
  final List<String> syllabusPoints;
  final List<CourseFaq> faqs;

  bool get isFree => feeAmount <= 0;

  double get payableAmount {
    final net = feeAmount - discountAmount;
    return net < 0 ? 0 : net;
  }

  bool get isPublished => status == 'published';

  bool get hasDemo =>
      demoMethods.isNotEmpty && !demoMethods.contains(CourseDemoMethod.noDemo);

  factory Course.fromJson(Map<String, dynamic> json) {
    final instituteRaw = json['institutes'];
    final institute = instituteRaw is Map<String, dynamic>
        ? instituteRaw
        : <String, dynamic>{};
    final batchesRaw = json['course_batches'];
    final batches = batchesRaw is List
        ? batchesRaw
            .whereType<Map<String, dynamic>>()
            .map(CourseBatch.fromJson)
            .toList()
        : const <CourseBatch>[];
    final facultyRaw = json['course_faculty'];
    final faculty = facultyRaw is List
        ? facultyRaw
            .whereType<Map<String, dynamic>>()
            .map(CourseFaculty.fromJson)
            .toList()
        : const <CourseFaculty>[];
    final faqsRaw = json['course_faqs'];
    final faqs = faqsRaw is List
        ? (faqsRaw
            .whereType<Map<String, dynamic>>()
            .map(CourseFaq.fromJson)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)))
        : const <CourseFaq>[];
    final syllabusRaw = json['syllabus_points'];
    final syllabusPoints = syllabusRaw is List
        ? syllabusRaw.whereType<String>().toList()
        : const <String>[];
    final methodsRaw = json['demo_methods'];
    final methods = methodsRaw is List
        ? methodsRaw
            .whereType<String>()
            .map(CourseDemoMethod.fromDb)
            .whereType<CourseDemoMethod>()
            .toList()
        : const <CourseDemoMethod>[];
    return Course(
      id: json['id'] as String? ?? '',
      instituteId: json['institute_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mode: CourseMode.fromDb(json['mode'] as String? ?? ''),
      venueId: json['venue_id'] as String? ?? '',
      durationWeeks: (json['duration_weeks'] as num?)?.toInt() ?? 1,
      feeAmount: (json['fee_amount'] as num?)?.toDouble() ?? 0,
      instructorName: json['instructor_name'] as String? ?? '',
      coverImage: json['cover_image'] as String? ?? '',
      status: json['status'] as String? ?? 'published',
      instituteName: institute['name'] as String? ?? '',
      instituteVerified: institute['is_verified'] as bool? ?? false,
      instituteCity: institute['city'] as String? ?? '',
      batches: batches,
      categoryId: json['category_id'] as String? ?? '',
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      demoMethods: methods,
      demoVideoUrl: json['demo_video_url'] as String? ?? '',
      demoThumbnailUrl: json['demo_thumbnail_url'] as String? ?? '',
      brochureUrl: json['brochure_url'] as String? ?? '',
      externalRegistrationUrl:
          json['external_registration_url'] as String? ?? '',
      contactPhone: json['contact_phone'] as String? ?? '',
      faculty: faculty,
      syllabusPoints: syllabusPoints,
      faqs: faqs,
    );
  }

  Course copyWith({
    List<CourseBatch>? batches,
    String? instituteName,
    bool? instituteVerified,
    String? status,
    List<CourseFaculty>? faculty,
    List<CourseFaq>? faqs,
  }) {
    return Course(
      id: id,
      instituteId: instituteId,
      title: title,
      description: description,
      mode: mode,
      venueId: venueId,
      durationWeeks: durationWeeks,
      feeAmount: feeAmount,
      instructorName: instructorName,
      coverImage: coverImage,
      status: status ?? this.status,
      instituteName: instituteName ?? this.instituteName,
      instituteVerified: instituteVerified ?? this.instituteVerified,
      instituteCity: instituteCity,
      batches: batches ?? this.batches,
      categoryId: categoryId,
      discountAmount: discountAmount,
      demoMethods: demoMethods,
      demoVideoUrl: demoVideoUrl,
      demoThumbnailUrl: demoThumbnailUrl,
      brochureUrl: brochureUrl,
      externalRegistrationUrl: externalRegistrationUrl,
      contactPhone: contactPhone,
      faculty: faculty ?? this.faculty,
      syllabusPoints: syllabusPoints,
      faqs: faqs ?? this.faqs,
    );
  }
}

/// An enrollable cohort of a course (`course_batches`).
class CourseBatch {
  const CourseBatch({
    required this.id,
    required this.courseId,
    required this.label,
    required this.startsOn,
    required this.capacity,
    required this.enrolledCount,
    this.isActive = true,
    this.userEnrolled = false,
    this.timing = '',
    this.endsOn,
    this.feeAmount = 0,
    this.mode,
    this.waitlistEnabled = false,
    this.waitlistCount = 0,
    this.admissionsOpen = true,
    this.subject = '',
    this.categorySlug = '',
  });

  final String id;
  final String courseId;
  final String label;
  final DateTime startsOn;
  final int capacity;
  final int enrolledCount;
  final bool isActive;
  final bool userEnrolled;
  final String timing;
  final DateTime? endsOn;
  final double feeAmount;
  final CourseMode? mode;
  final bool waitlistEnabled;
  final int waitlistCount;
  final bool admissionsOpen;
  final String subject;
  final String categorySlug;

  int get seatsLeft {
    final left = capacity - enrolledCount;
    return left < 0 ? 0 : left;
  }

  bool get isFull => seatsLeft <= 0;

  bool get isOngoingToday {
    final today = DateTime.now();
    final start = DateTime(startsOn.year, startsOn.month, startsOn.day);
    final end = endsOn == null
        ? start.add(const Duration(days: 90))
        : DateTime(endsOn!.year, endsOn!.month, endsOn!.day);
    final now = DateTime(today.year, today.month, today.day);
    return !now.isBefore(start) && !now.isAfter(end);
  }

  factory CourseBatch.fromJson(Map<String, dynamic> json) => CourseBatch(
        id: json['id'] as String? ?? '',
        courseId: json['course_id'] as String? ?? '',
        label: json['label'] as String? ?? json['title'] as String? ?? '',
        startsOn: DateTime.tryParse(json['starts_on'] as String? ?? '') ??
            DateTime.tryParse(json['start_date'] as String? ?? '') ??
            DateTime(1970),
        capacity: (json['capacity'] as num?)?.toInt() ??
            (json['max_capacity'] as num?)?.toInt() ??
            0,
        enrolledCount: (json['enrolled_count'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        userEnrolled: json['user_enrolled'] as bool? ?? false,
        timing: json['timing'] as String? ?? '',
        endsOn: DateTime.tryParse(json['ends_on'] as String? ?? ''),
        feeAmount: (json['fee_amount'] as num?)?.toDouble() ?? 0,
        mode: json['mode'] is String
            ? CourseMode.fromDb(json['mode'] as String)
            : null,
        waitlistEnabled: json['waitlist_enabled'] as bool? ?? false,
        waitlistCount: (json['waitlist_count'] as num?)?.toInt() ?? 0,
        admissionsOpen: json['admissions_open'] as bool? ?? true,
        subject: json['subject'] as String? ?? '',
        categorySlug: json['category_slug'] as String? ?? '',
      );

  CourseBatch copyWith({
    int? enrolledCount,
    bool? userEnrolled,
    bool? isActive,
    String? timing,
    DateTime? endsOn,
    double? feeAmount,
    CourseMode? mode,
    bool? waitlistEnabled,
    int? waitlistCount,
    bool? admissionsOpen,
    String? subject,
    String? categorySlug,
  }) {
    return CourseBatch(
      id: id,
      courseId: courseId,
      label: label,
      startsOn: startsOn,
      capacity: capacity,
      enrolledCount: enrolledCount ?? this.enrolledCount,
      isActive: isActive ?? this.isActive,
      userEnrolled: userEnrolled ?? this.userEnrolled,
      timing: timing ?? this.timing,
      endsOn: endsOn ?? this.endsOn,
      feeAmount: feeAmount ?? this.feeAmount,
      mode: mode ?? this.mode,
      waitlistEnabled: waitlistEnabled ?? this.waitlistEnabled,
      waitlistCount: waitlistCount ?? this.waitlistCount,
      admissionsOpen: admissionsOpen ?? this.admissionsOpen,
      subject: subject ?? this.subject,
      categorySlug: categorySlug ?? this.categorySlug,
    );
  }
}

/// A structured faculty / instructor profile (`course_faculty`).
class CourseFaculty {
  const CourseFaculty({
    required this.id,
    required this.courseId,
    required this.name,
    this.role = '',
    this.bio = '',
    this.photoUrl = '',
  });

  final String id;
  final String courseId;
  final String name;
  final String role;
  final String bio;
  final String photoUrl;

  factory CourseFaculty.fromJson(Map<String, dynamic> json) => CourseFaculty(
        id: json['id'] as String? ?? '',
        courseId: json['course_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        photoUrl: json['photo_url'] as String? ?? '',
      );
}

/// A frequently asked question attached to a course (`course_faqs`).
class CourseFaq {
  const CourseFaq({
    required this.id,
    required this.courseId,
    required this.question,
    required this.answer,
    this.displayOrder = 0,
  });

  final String id;
  final String courseId;
  final String question;
  final String answer;
  final int displayOrder;

  factory CourseFaq.fromJson(Map<String, dynamic> json) => CourseFaq(
        id: json['id'] as String? ?? '',
        courseId: json['course_id'] as String? ?? '',
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      );
}

/// Result of `enroll_in_course` / `enroll_in_course_details`.
class CourseEnrollmentRecord {
  const CourseEnrollmentRecord({
    required this.id,
    required this.batchId,
    required this.status,
    this.isTrial = false,
    this.admissionCode = '',
    this.studentName = '',
    this.contactPhone = '',
  });

  final String id;
  final String batchId;
  final String status;
  final bool isTrial;
  final String admissionCode;
  final String studentName;
  final String contactPhone;

  factory CourseEnrollmentRecord.fromJson(Map<String, dynamic> json) =>
      CourseEnrollmentRecord(
        id: json['id'] as String? ?? '',
        batchId: json['batch_id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        isTrial: json['is_trial'] as bool? ?? false,
        admissionCode: json['admission_code'] as String? ?? '',
        studentName: json['student_name'] as String? ?? '',
        contactPhone: json['contact_phone'] as String? ?? '',
      );
}

/// A learner's request for an internal demo class
/// (`course_demo_registrations`).
class CourseDemoRegistration {
  const CourseDemoRegistration({
    required this.id,
    required this.courseId,
    required this.studentName,
    required this.mobile,
    this.email = '',
    this.preferredBatch = '',
    this.note = '',
    this.status = 'pending',
  });

  final String id;
  final String courseId;
  final String studentName;
  final String mobile;
  final String email;
  final String preferredBatch;
  final String note;
  final String status;

  factory CourseDemoRegistration.fromJson(Map<String, dynamic> json) =>
      CourseDemoRegistration(
        id: json['id'] as String? ?? '',
        courseId: json['course_id'] as String? ?? '',
        studentName: json['student_name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        email: json['email'] as String? ?? '',
        preferredBatch: json['preferred_batch'] as String? ?? '',
        note: json['note'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
      );
}

/// Post-course feedback and rating (`course_feedback`), gated by enrollment.
class CourseFeedback {
  const CourseFeedback({
    required this.id,
    required this.courseId,
    required this.rating,
    this.comment = '',
    this.authorName = '',
  });

  final String id;
  final String courseId;
  final int rating;
  final String comment;
  final String authorName;

  factory CourseFeedback.fromJson(Map<String, dynamic> json) => CourseFeedback(
        id: json['id'] as String? ?? '',
        courseId: json['course_id'] as String? ?? '',
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        comment: json['comment'] as String? ?? '',
        authorName: json['author_name'] as String? ?? '',
      );
}

/// A learner's active enrollment joined to its course and batch, used by the
/// My Courses screen (`my_enrolled_batches` + `courses`).
class MyEnrolledCourse {
  const MyEnrolledCourse({
    required this.course,
    required this.batch,
    this.enrolledAt,
  });

  final Course course;
  final CourseBatch batch;
  final DateTime? enrolledAt;
}

/// A generated education invoice. Client-composed from an enrollment and the
/// course fee breakdown until a server-side invoice entity exists.
class EducationInvoice {
  const EducationInvoice({
    required this.number,
    required this.courseTitle,
    required this.instituteName,
    required this.batchLabel,
    required this.studentName,
    required this.feeAmount,
    required this.discountAmount,
    required this.issuedAt,
    this.status = 'paid',
  });

  final String number;
  final String courseTitle;
  final String instituteName;
  final String batchLabel;
  final String studentName;
  final double feeAmount;
  final double discountAmount;
  final DateTime issuedAt;
  final String status;

  double get netAmount {
    final net = feeAmount - discountAmount;
    return net < 0 ? 0 : net;
  }
}
