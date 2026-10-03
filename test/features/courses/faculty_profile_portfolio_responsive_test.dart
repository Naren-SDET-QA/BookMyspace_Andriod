import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/domain/course_repository.dart';
import 'package:bookmyspace/features/courses/domain/sample_education_data.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/widgets/batch_class_card.dart';
import 'package:bookmyspace/features/courses/presentation/widgets/faculty_credentials_sheet.dart';

class _FakeCourseRepository implements CourseRepository {
  @override
  Future<List<Course>> publishedCourses({String? category, String? query}) async =>
      sampleCourses;

  @override
  Future<Course> courseDetail(String id) async =>
      sampleCourses.firstWhere((c) => c.id == id, orElse: () => sampleCourses.first);

  @override
  Future<List<Institute>> institutes({String? query}) async => sampleInstitutes;

  @override
  Future<Institute> instituteDetail(String id) async => sampleInstitutes.first;

  @override
  Future<List<CourseFeedback>> courseFeedback(String courseId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child, [CourseRepository? repo]) {
  return ProviderScope(
    overrides: [
      courseRepositoryProvider.overrideWithValue(repo ?? _FakeCourseRepository()),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('Faculty profile modal displays all credentials, stats and quote', (tester) async {
    final course = sampleCourses.first;
    final faculty = course.faculty.first;

    await tester.pumpWidget(_wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showFacultyCredentialsSheet(
            context,
            course: course,
            faculty: faculty,
          ),
          child: const Text('Open Profile'),
        ),
      ),
    ));

    await tester.tap(find.text('Open Profile'));
    await tester.pumpAndSettle();

    // Verify header
    expect(find.text('Faculty Profile & Portfolio'), findsOneWidget);
    expect(find.text('Verified Instructor Credentials'), findsOneWidget);

    // Verify hero card & stats
    expect(find.byKey(const Key('instructor-hero')), findsOneWidget);
    expect(find.text('Coach Srinivas Rao'), findsOneWidget);
    expect(find.text('Chief Coach (BWF Level 3)'), findsOneWidget);
    expect(find.textContaining('Osmania University'), findsOneWidget);

    expect(find.byKey(const Key('stat-experience')), findsOneWidget);
    expect(find.byKey(const Key('stat-students')), findsOneWidget);
    expect(find.byKey(const Key('stat-rating')), findsOneWidget);
    expect(find.byKey(const Key('stat-batches')), findsOneWidget);

    // Verify action buttons
    expect(find.byKey(const Key('instructor-call')), findsOneWidget);
    expect(find.byKey(const Key('instructor-whatsapp')), findsOneWidget);

    // Verify Biography & Philosophy
    expect(find.text('Biography & Background'), findsOneWidget);
    expect(find.byKey(const Key('instructor-philosophy')), findsOneWidget);
    expect(find.text('TEACHING PHILOSOPHY'), findsOneWidget);
    expect(find.textContaining('Discipline in footwork builds confidence in rallies'), findsOneWidget);

    // Verify Official Certifications
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('Official Certifications & Credentials'), findsOneWidget);
    expect(find.textContaining('Verified'), findsWidgets);
    expect(find.textContaining('BWF (Badminton World Federation)'), findsOneWidget);

    // Verify Honors & Key Achievements
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(find.text('Honors & Key Achievements'), findsOneWidget);
    expect(find.textContaining('Mentored 18 National Junior Ranking'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Faculty profile modal is fully responsive across all device sizes without overflow', (tester) async {
    final viewports = [
      const Size(320, 640),   // Small Phone
      const Size(390, 844),   // Modern iPhone
      const Size(412, 915),   // Android Flagship
      const Size(600, 960),   // Foldable
      const Size(768, 1024),  // iPad Mini / Tablet
      const Size(1024, 768),  // Tablet Landscape
      const Size(1280, 800),  // Desktop
      const Size(1440, 900),  // Mac Display
      const Size(1920, 1080), // 1080p Monitor
    ];

    for (final size in viewports) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      final course = sampleCourses.first;
      final faculty = course.faculty.first;

      await tester.pumpWidget(_wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showFacultyCredentialsSheet(
              context,
              course: course,
              faculty: faculty,
            ),
            child: const Text('Open Profile'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Faculty Profile & Portfolio'), findsOneWidget);
      expect(find.byKey(const Key('instructor-hero')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll up and down to check all items render with 0 overflow
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Close modal for next iteration
      Navigator.of(tester.element(find.byType(ListView))).pop();
      await tester.pumpAndSettle();
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
