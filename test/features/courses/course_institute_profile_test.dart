import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/screens/institute_detail_screen.dart';
import 'package:bookmyspace/features/courses/presentation/screens/instructor_profile_screen.dart';
import 'package:bookmyspace/features/courses/presentation/widgets/course_spec_card.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../events/mock_event_repository.dart';
import '../reviews/mock_review_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'mock_course_repository.dart';

const _user = AuthUser(id: 'u1', email: 'a@b.com');

const _coach = CourseFaculty(
  id: 'f1',
  courseId: 'c1',
  instituteId: 'i1',
  name: 'Coach Ravi',
  designation: 'Senior Coach',
  qualification: 'NIS Certified',
  experienceText: '8 yrs exp',
  bio: 'Former state-level player.',
  skills: ['Footwork'],
  languages: ['Telugu'],
);

Course _course({String id = 'c1', String title = 'Badminton Pro Batch'}) {
  return MockCourseRepository.sampleCourse(id: id, title: title).copyWith(
    faculty: [
      CourseFaculty(
        id: id == 'c1' ? 'f1' : 'f2',
        courseId: id,
        instituteId: 'i1',
        name: 'Coach Ravi',
        designation: 'Senior Coach',
        qualification: 'NIS Certified',
        experienceText: '8 yrs exp',
        bio:
            'Former state-level player.\n'
            'Teaching philosophy: "Think two shots ahead."',
      ),
    ],
    batches: [
      CourseBatch(
        id: '${id}b0',
        courseId: id,
        label: 'Morning Batch',
        startsOn: DateTime.now().add(const Duration(days: 3)),
        capacity: 25,
        enrolledCount: 3,
        timing: '7:30 AM',
        categorySlug: 'sports_fitness',
      ),
    ],
  );
}

Widget _app(MockCourseRepository repo, String location) {
  return ProviderScope(
    overrides: [
      courseRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: _user),
      ),
      venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
      eventRepositoryProvider.overrideWithValue(MockEventRepository()),
      reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
      featureFlagsProvider.overrideWith((ref) async {
        return {
          'courses': const FeatureFlag(
            key: 'courses',
            enabled: true,
            platforms: ['ios', 'android', 'web'],
            config: {},
          ),
        };
      }),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: location,
        currentUser: _user,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

MockCourseRepository _repo() => MockCourseRepository()
  ..courses = [_course(), _course(id: 'c2', title: 'Weekend Smash Clinic')]
  ..branchList = const [
    InstituteBranch(
      id: 'br1',
      instituteId: 'i1',
      address: 'Maitrivanam, Ameerpet',
      city: 'Hyderabad',
      isPrimary: true,
    ),
  ];

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('course page shows badges, spec card and instructor card', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_repo(), '/courses/c1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('course-mode-badge')), findsOneWidget);
    expect(find.text('Sports & Fitness'), findsOneWidget);
    expect(find.byKey(const Key('course-institute-link')), findsOneWidget);

    await _scrollTo(tester, find.byKey(const Key('spec-seats')));
    expect(find.text('FACULTY & BATCH SPECIFICATIONS'), findsOneWidget);
    expect(find.text('Coach Ravi (Senior Coach)'), findsOneWidget);
    expect(find.text('NIS Certified • 8 yrs exp'), findsOneWidget);
    expect(find.text('7:30 AM'), findsOneWidget);
    expect(find.text('2 Months'), findsOneWidget);
    expect(find.text('Maitrivanam, Ameerpet, Hyderabad'), findsOneWidget);
    expect(find.text('22 seats left (Total: 25)'), findsOneWidget);

    await _scrollTo(tester, find.byKey(const Key('instructor-card-f1')));
    expect(
      find.text("View Coach Ravi's Certifications, Bio & All Batches →"),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('instructor card opens profile with all batches', (tester) async {
    await tester.pumpWidget(_app(_repo(), '/courses/c1'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('instructor-card-f1')));
    await tester.tap(find.byKey(const Key('instructor-card-f1')));
    await tester.pumpAndSettle();

    expect(find.byType(InstructorProfileScreen), findsOneWidget);
    expect(find.text('Faculty Profile & Portfolio'), findsOneWidget);
    expect(find.text('Coach Ravi'), findsOneWidget);
    expect(find.text('Senior Coach'), findsOneWidget);
    expect(find.text('8 Yrs'), findsOneWidget);
    expect(find.text('6+'), findsOneWidget); // 3 enrolled in each course
    expect(find.text('2 Batches'), findsOneWidget);
    expect(find.text('Former state-level player.'), findsOneWidget);
    expect(find.byKey(const Key('instructor-philosophy')), findsOneWidget);
    expect(find.text('"Think two shots ahead."'), findsOneWidget);
    expect(find.text('1 Verified'), findsOneWidget);
    await _scrollTo(tester, find.text('All Batches (2)'));
    await _scrollTo(tester, find.byKey(const Key('instructor-course-c2')));
    expect(find.text('Weekend Smash Clinic'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('institute name opens the institute profile', (tester) async {
    await tester.pumpWidget(_app(_repo(), '/courses/c1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('course-institute-link')));
    await tester.pumpAndSettle();
    expect(find.byType(InstituteDetailScreen), findsOneWidget);
  });

  testWidgets('profile fits a 320px phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_repo(), '/instructors/f1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('instructor-hero')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_app(_repo(), '/courses/c1'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('instructor-card-f1')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown instructor shows not found', (tester) async {
    await tester.pumpWidget(_app(_repo(), '/instructors/nope'));
    await tester.pumpAndSettle();
    expect(find.text('Instructor not found'), findsOneWidget);
  });

  test('helpers', () {
    expect(humanizeSlug('sports_fitness'), 'Sports & Fitness');
    expect(humanizeSlug('coding'), 'Coding');
    expect(courseDurationLabel(12), '3 Months');
    expect(courseDurationLabel(6), '6 weeks');
    expect(campusLocationLabel(fallbackCity: 'Hyderabad'), 'Hyderabad');
    final profile = findInstructorProfile([_course(), _course(id: 'c2')], 'f2');
    expect(profile?.faculty.name, _coach.name);
    expect(profile?.courses.length, 2);
    expect(findInstructorProfile([_course()], 'missing'), isNull);
    expect(experienceBadge('14+ years coaching'), '14+ Yrs');
    expect(experienceBadge('senior'), '');
    final split = splitPhilosophy('Coach.\nPhilosophy: Discipline first.');
    expect(split.bio, 'Coach.');
    expect(split.philosophy, 'Discipline first.');
    expect(
      facultyCredentials(
        const CourseFaculty(
          id: 'x',
          courseId: 'c',
          name: 'n',
          qualification: 'BWF Level 3; NIS Certified',
          specialization: 'Footwork',
        ),
      ),
      ['BWF Level 3', 'NIS Certified', 'Footwork'],
    );
  });
}
