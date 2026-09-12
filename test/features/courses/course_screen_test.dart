import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/screens/course_detail_screen.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
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

List<Override> _overrides(
  MockCourseRepository courses, {
  AuthUser? user = const AuthUser(id: 'u1', email: 'a@b.com'),
}) {
  return [
    courseRepositoryProvider.overrideWithValue(courses),
    authRepositoryProvider.overrideWithValue(
      MockAuthRepository(initialUser: user),
    ),
    venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
    eventRepositoryProvider.overrideWithValue(MockEventRepository()),
    reviewRepositoryProvider.overrideWithValue(MockReviewRepository()),
  ];
}

Widget _detailApp(
  MockCourseRepository repo, {
  AuthUser? user = const AuthUser(id: 'u1', email: 'a@b.com'),
}) {
  return ProviderScope(
    overrides: _overrides(repo, user: user),
    child: const MaterialApp(
      home: CourseDetailScreen(courseId: 'c1'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Widget _routerApp(
  MockCourseRepository repo, {
  required String location,
  AuthUser? user = const AuthUser(id: 'u1', email: 'a@b.com'),
  bool allowPreview = false,
}) {
  return ProviderScope(
    overrides: _overrides(repo, user: user),
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

void main() {
  testWidgets('course list shows empty state', (tester) async {
    await tester.pumpWidget(
      _routerApp(MockCourseRepository(), location: AppRoutes.coursesList),
    );
    await tester.pumpAndSettle();
    expect(find.text('No courses available'), findsOneWidget);
  });

  testWidgets('course list shows cards and opens detail', (tester) async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(
      _routerApp(repo, location: AppRoutes.coursesList),
    );
    await tester.pumpAndSettle();
    expect(find.text('Flutter App Development Bootcamp'), findsOneWidget);
    expect(find.text('Nexus Learning Institute'), findsOneWidget);
    expect(find.text('8 weeks'), findsOneWidget);

    await tester.tap(find.text('Flutter App Development Bootcamp'));
    await tester.pumpAndSettle();
    expect(find.byType(CourseDetailScreen), findsOneWidget);
    expect(find.textContaining('Anand Kumar'), findsOneWidget);
  });

  testWidgets('course list error retries', (tester) async {
    final repo = MockCourseRepository()..failList = true;
    await tester.pumpWidget(
      _routerApp(repo, location: AppRoutes.coursesList),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);

    repo
      ..failList = false
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter App Development Bootcamp'), findsOneWidget);
  });

  testWidgets('shows course details and batches with enroll buttons', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Flutter App Development Bootcamp'), findsOneWidget);
    expect(find.text('Nexus Learning Institute'), findsOneWidget);

    await _scrollTo(tester, find.text('Weekday Batch A'));
    expect(find.text('Weekday Batch A'), findsOneWidget);
    expect(find.text('22 seats left'), findsOneWidget);
    expect(find.text('Enroll Now'), findsWidgets);
  });

  testWidgets('enrolling calls the repository and shows enrolled state', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Weekday Batch A'));
    await tester.tap(find.text('Enroll Now').first);
    await tester.pumpAndSettle();

    expect(repo.lastEnrollBatchId, 'b0');
    expect(find.text('Enrolled'), findsOneWidget);
    expect(find.text('Drop'), findsOneWidget);
  });

  testWidgets('already enrolled batch can be dropped', (tester) async {
    final course = MockCourseRepository.sampleCourse();
    final enrolled = course.copyWith(
      batches: [
        course.batches.first.copyWith(userEnrolled: true, enrolledCount: 4),
      ],
    );
    final repo = MockCourseRepository()..courses = [enrolled];
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Drop'));
    await tester.tap(find.text('Drop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo.lastDropBatchId, 'b0');
  });

  testWidgets('a full batch disables enrollment', (tester) async {
    final course = MockCourseRepository.sampleCourse();
    final repo = MockCourseRepository()
      ..courses = [
        course.copyWith(
          batches: [
            CourseBatch(
              id: 'bfull',
              courseId: course.id,
              label: 'Full Batch',
              startsOn: DateTime.now().add(const Duration(days: 30)),
              capacity: 25,
              enrolledCount: 25,
            ),
          ],
        ),
      ];
    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Full Batch'));
    expect(find.text('Sold Out'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('unsigned enroll navigates to login', (tester) async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()];
    await tester.pumpWidget(
      _routerApp(
        repo,
        location: '/courses/c1',
        user: null,
        allowPreview: true,
      ),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Sign in to enroll').first);
    await tester.tap(find.text('Sign in to enroll').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign in'), findsWidgets);
    expect(repo.lastEnrollBatchId, isNull);
  });
}
