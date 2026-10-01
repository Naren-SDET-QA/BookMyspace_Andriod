import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/domain/course_waitlist.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_waitlist_providers.dart';
import 'package:bookmyspace/features/courses/presentation/screens/courses_list_screen.dart';
import 'package:bookmyspace/features/courses/presentation/screens/education_hub_screen.dart';
import 'package:bookmyspace/features/courses/presentation/screens/owner_institute_dashboard_screen.dart';
import 'package:bookmyspace/features/modules/domain/feature_flag.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_course_repository.dart';

class _QuietWaitlist implements CourseWaitlistRepository {
  @override
  Future<int> join(String batchId) async => 1;

  @override
  Future<void> leave(String batchId) async {}

  @override
  Future<List<CourseWaitlistEntry>> mine() async => const [];
}

Widget _app(Widget home, MockCourseRepository repo) {
  return ProviderScope(
    overrides: [
      courseRepositoryProvider.overrideWithValue(repo),
      courseWaitlistRepositoryProvider.overrideWithValue(_QuietWaitlist()),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(
            id: 'u1',
            email: 'owner@example.com',
            fullName: 'Asha',
            phone: '9000000000',
          ),
        ),
      ),
      featureFlagsProvider.overrideWith(
        (ref) async => {
          'courses': const FeatureFlag(
            key: 'courses',
            enabled: true,
            platforms: ['ios', 'android', 'web'],
            config: {},
          ),
        },
      ),
    ],
    child: MaterialApp(
      home: home,
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

void main() {
  const sizes = [Size(320, 700), Size(834, 1100), Size(1280, 800)];

  testWidgets('courses filters stay on screen at phone, tablet, and desktop', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(const CoursesListScreen(), repo));
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);
      expect(find.text('All modes'), findsWidgets);
      expect(find.text('Ongoing today'), findsWidgets);
      expect(find.text('Full / waitlist'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('education hub chips and location fit every width', (
    tester,
  ) async {
    final repo = MockCourseRepository()
      ..instituteList = [MockCourseRepository.sampleInstitute()]
      ..courses = [MockCourseRepository.sampleCourse()];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(const EducationHubScreen(), repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('10 km'), findsWidgets);
      expect(
        find.byKey(
          const Key('education-mode-online'),
          skipOffstage: size.width < 600,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('education-ongoing-today'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('education-full-waitlist'), skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('owner tabs are reachable on phone and desktop', (tester) async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse()]
      ..instituteList = [MockCourseRepository.sampleInstitute()];
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const labels = [
      'Batches',
      'Admissions',
      'Faculty',
      'Registration',
      'Branches',
      'Settings',
      'Profile',
    ];
    for (final size in const [
      Size(320, 700),
      Size(844, 390),
      Size(1280, 800),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _app(const OwnerInstituteDashboardScreen(), repo),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('owner-badge')), findsOneWidget);
      if (size.height >= 520) {
        expect(find.byKey(const Key('owner-capacity-gauge')), findsOneWidget);
      }
      final tabScroll = find.descendant(
        of: find.byKey(const Key('owner-dashboard-tabs')),
        matching: find.byType(Scrollable),
      );
      for (final label in labels) {
        await tester.scrollUntilVisible(
          find.text(label),
          120,
          scrollable: tabScroll,
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label @ $size');
      }
    }
  });
}
