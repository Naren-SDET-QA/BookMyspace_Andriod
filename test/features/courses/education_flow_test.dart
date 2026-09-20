import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/screens/course_detail_screen.dart';
import 'package:bookmyspace/features/courses/presentation/screens/education_hub_screen.dart';
import 'package:bookmyspace/features/courses/presentation/screens/institute_detail_screen.dart';
import 'package:bookmyspace/features/courses/presentation/screens/my_courses_screen.dart';
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

const _user = AuthUser(id: 'u1', email: 'a@b.com', fullName: 'Asha Learner');

List<Override> _overrides(
  MockCourseRepository courses, {
  AuthUser? user = _user,
  Set<AppRole> roles = const {AppRole.customer},
  Map<String, FeatureFlag>? flags,
}) {
  return [
    courseRepositoryProvider.overrideWithValue(courses),
    authRepositoryProvider.overrideWithValue(
      MockAuthRepository(initialUser: user),
    ),
    currentUserRolesProvider.overrideWith((ref) async => roles),
    venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
    eventRepositoryProvider.overrideWithValue(MockEventRepository()),
    reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
    if (flags != null) featureFlagsProvider.overrideWith((ref) async => flags),
  ];
}

Widget _routerApp(
  MockCourseRepository repo, {
  required String location,
  AuthUser? user = _user,
  Set<AppRole> roles = const {AppRole.customer},
  bool allowPreview = false,
  Map<String, FeatureFlag>? flags,
}) {
  return ProviderScope(
    overrides: _overrides(repo, user: user, roles: roles, flags: flags),
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: location,
        currentUser: user,
        allowUnauthenticatedPreview: allowPreview,
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

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

FeatureFlag _off(String key) => FeatureFlag(
      key: key,
      enabled: false,
      platforms: const ['ios', 'android', 'web'],
      config: const {},
    );

void main() {
  // -- Journey: login redirect preserves the education destination ----------
  test('login redirect round-trips a protected education destination', () {
    final login = loginLocationFor(Uri.parse(AppRoutes.myCourses));
    expect(login, startsWith(AppRoutes.login));
    expect(login, contains('redirect='));
    final back = authenticatedLocationFromLogin(Uri.parse(login));
    expect(back, AppRoutes.myCourses);
  });

  // -- Journey: Home -> Education -> Institute list -------------------------
  testWidgets('education hub lists institutes', (tester) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()];
    await tester.pumpWidget(_routerApp(repo, location: AppRoutes.education));
    await tester.pumpAndSettle();

    expect(find.byType(EducationHubScreen), findsOneWidget);
    // Institute name appears in multiple sections (featured + all), so use findsAtLeastNWidgets
    expect(find.text('Nexus Learning Institute'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Private'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('featured-institute-i1')), findsOneWidget);
    expect(find.text('Education & Institutes'), findsOneWidget);
    expect(find.text('Search Available'), findsOneWidget);
    expect(find.text('44% OFF'), findsNothing);
    expect(find.textContaining('4.8'), findsNothing);
  });

  testWidgets('education hub discovery layout fits 320 and 1024', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [Size(320, 640), Size(1024, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_routerApp(repo, location: AppRoutes.education));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Education & Institutes'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('all-institutes-i1')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nexus Learning Institute'), findsAtLeastNWidgets(1));
    }
  });

  testWidgets('education hub shows empty state with no institutes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _routerApp(MockCourseRepository(), location: AppRoutes.education),
    );
    await tester.pumpAndSettle();
    expect(find.text('No institutes yet'), findsOneWidget);
  });

  // -- Journey: Education -> Category (browse all courses) ------------------
  testWidgets('browse all courses navigates to the course list', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()]
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(_routerApp(repo, location: AppRoutes.education));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courses').first);
    await tester.pumpAndSettle();
    expect(find.text('Flutter App Development Bootcamp'), findsOneWidget);
  });

  // -- Journey: Institute list -> Institute details -> Course list ----------
  testWidgets('institute card opens institute details with its courses', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()]
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(_routerApp(repo, location: AppRoutes.education));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const Key('all-institutes-i1')));
    await tester.tap(find.byKey(const Key('all-institutes-i1')));
    await tester.pumpAndSettle();

    expect(find.byType(InstituteDetailScreen), findsOneWidget);
    expect(find.text('Courses offered'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    await _scrollTo(tester, find.text('Flutter App Development Bootcamp'));
    expect(find.text('Flutter App Development Bootcamp'), findsOneWidget);
  });

  testWidgets('institute details error retries', (tester) async {
    final repo = MockCourseRepository()..failInstituteDetail = true;
    await tester.pumpWidget(
      _routerApp(repo, location: '/institutes/i1'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);

    repo
      ..failInstituteDetail = false
      ..instituteList = [MockCourseRepository.sampleInstitute()];
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Nexus Learning Institute'), findsWidgets);
  });

  // -- Journey: Course details -> demo (register for demo internal form) ----
  testWidgets('course demo section registers a demo request', (tester) async {
    final base = MockCourseRepository.sampleCourse();
    final course = Course(
      id: base.id,
      instituteId: base.instituteId,
      title: base.title,
      description: base.description,
      mode: base.mode,
      durationWeeks: base.durationWeeks,
      feeAmount: base.feeAmount,
      status: base.status,
      instituteName: base.instituteName,
      batches: base.batches,
      demoMethods: const [CourseDemoMethod.internalForm],
    );
    final repo = MockCourseRepository()..courses = [course];
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repo),
        child: MaterialApp(
          home: const CourseDetailScreen(courseId: 'c1'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Register for Demo'));
    await tester.tap(find.text('Register for Demo'));
    await tester.pumpAndSettle();

    // Fill the internal demo form and submit.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Student name'),
      'Asha',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number'),
      '9000000000',
    );
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('demo:c1:Asha:9000000000'));
  });

  // -- Journey: Course details -> fee breakdown with discount ---------------
  testWidgets('course detail shows a fee breakdown with discount', (
    tester,
  ) async {
    final base = MockCourseRepository.sampleCourse();
    final course = Course(
      id: base.id,
      instituteId: base.instituteId,
      title: base.title,
      description: base.description,
      mode: base.mode,
      durationWeeks: base.durationWeeks,
      feeAmount: 10000,
      status: base.status,
      instituteName: base.instituteName,
      batches: base.batches,
      discountAmount: 2000,
    );
    final repo = MockCourseRepository()..courses = [course];
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repo),
        child: MaterialApp(
          home: const CourseDetailScreen(courseId: 'c1'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Fee breakdown'));
    expect(find.text('Fee breakdown'), findsOneWidget);
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('Total payable'), findsOneWidget);
  });

  // -- Journey: My Courses (signed out) preserves destination ---------------
  testWidgets('my courses prompts sign-in when logged out', (tester) async {
    await tester.pumpWidget(
      _routerApp(
        MockCourseRepository(),
        location: AppRoutes.myCourses,
        user: null,
        allowPreview: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MyCoursesScreen), findsOneWidget);
    expect(find.text('Sign in to enroll'), findsWidgets);
  });

  // -- Journey: My Courses (signed in) -> invoice + feedback ----------------
  testWidgets('my courses lists enrollment and opens the invoice', (
    tester,
  ) async {
    final base = MockCourseRepository.sampleCourse();
    final enrolled = base.copyWith(
      batches: [base.batches.first.copyWith(userEnrolled: true)],
    );
    final repo = MockCourseRepository()..courses = [enrolled];
    await tester.pumpWidget(_routerApp(repo, location: AppRoutes.myCourses));
    await tester.pumpAndSettle();

    expect(find.text('Flutter App Development Bootcamp'), findsOneWidget);
    await tester.tap(find.text('View invoice'));
    await tester.pumpAndSettle();
    expect(find.text('Invoice'), findsWidgets);
    expect(find.textContaining('EDU-'), findsOneWidget);
  });

  testWidgets('my courses opens feedback and submits a rating', (
    tester,
  ) async {
    final base = MockCourseRepository.sampleCourse();
    final enrolled = base.copyWith(
      batches: [base.batches.first.copyWith(userEnrolled: true)],
    );
    final repo = MockCourseRepository()..courses = [enrolled];
    await tester.pumpWidget(_routerApp(repo, location: AppRoutes.myCourses));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();
    expect(find.text('Write feedback'), findsOneWidget);

    // Pick 5 stars then submit.
    await tester.tap(find.byIcon(Icons.star_border_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(repo.calls.any((c) => c.startsWith('feedback:c1:')), isTrue);
  });

  testWidgets('my courses shows empty state with no enrollments', (
    tester,
  ) async {
    await tester.pumpWidget(
      _routerApp(MockCourseRepository(), location: AppRoutes.myCourses),
    );
    await tester.pumpAndSettle();
    expect(find.text('No enrollments yet'), findsOneWidget);
  });

  // -- Journey: Owner manages their own courses -----------------------------
  testWidgets('owner sees their course list with status chips', (tester) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()]
      ..courses = [
        MockCourseRepository.sampleCourse(),
        MockCourseRepository.sampleCourse(id: 'c2', title: 'Draft Course')
            .copyWith(status: 'draft'),
      ];
    await tester.pumpWidget(
      _routerApp(
        repo,
        location: AppRoutes.ownerCourses,
        roles: const {AppRole.instituteOwner},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My courses'), findsOneWidget);
    expect(find.text('Flutter App Development Bootcamp'), findsOneWidget);
    expect(find.text('Draft Course'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('customer is denied the owner courses area', (tester) async {
    await tester.pumpWidget(
      _routerApp(
        MockCourseRepository(),
        location: AppRoutes.ownerCourses,
        roles: const {AppRole.customer},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('owner can create and publish a course', (tester) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()];
    await tester.pumpWidget(
      _routerApp(
        repo,
        location: AppRoutes.ownerCourseCreate,
        roles: const {AppRole.instituteOwner},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New course'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Course title'),
      'Advanced Flutter',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Duration (weeks)'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fee (₹)'),
      '15000',
    );
    await _scrollTo(tester, find.text('Publish'));
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(
      repo.calls
          .any((c) => c.startsWith('saveCourse:') && c.endsWith('published')),
      isTrue,
    );
  });

  // -- Journey: Admin manages the education catalog -------------------------
  testWidgets('administrator opens the education console', (tester) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()]
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(
      _routerApp(
        repo,
        location: AppRoutes.adminEducation,
        roles: const {AppRole.administrator},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Education'), findsOneWidget);
    expect(find.text('Institutes'), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Nexus Learning Institute'), findsOneWidget);
  });

  testWidgets('customer is denied the admin education console', (tester) async {
    await tester.pumpWidget(
      _routerApp(
        MockCourseRepository(),
        location: AppRoutes.adminEducation,
        roles: const {AppRole.customer},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
  });

  // -- Journey: module gating hides the education surface -------------------
  testWidgets('disabling the courses module hides the education hub', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()];
    await tester.pumpWidget(
      _routerApp(
        repo,
        location: AppRoutes.education,
        flags: {'courses': _off('courses')},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nexus Learning Institute'), findsNothing);
    expect(find.text('Education is unavailable'), findsOneWidget);
  });
}
