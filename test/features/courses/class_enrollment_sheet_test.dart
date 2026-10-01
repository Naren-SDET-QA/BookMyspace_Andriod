import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/cms/domain/configurable_form.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/widgets/class_enrollment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_course_repository.dart';

Course _course(CourseMode mode) {
  final base = MockCourseRepository.sampleCourse(batchCount: 1);
  return Course(
    id: base.id,
    instituteId: base.instituteId,
    title: base.title,
    description: base.description,
    mode: mode,
    durationWeeks: base.durationWeeks,
    feeAmount: base.feeAmount,
    status: base.status,
    batches: base.batches,
  );
}

Widget _app(MockCourseRepository repo, Course course) {
  return ProviderScope(
    overrides: [
      courseRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        ),
      ),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showClassEnrollmentSheet(
                context,
                course: course,
                batch: course.batches.first,
                isTrial: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _fillForm(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Asha Rao');
  await tester.enterText(fields.at(1), '9876543210');
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hybrid batch: mode preference and required terms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = MockCourseRepository();
    final course = _course(CourseMode.hybrid);
    await tester.pumpWidget(_app(repo, course));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('enroll-mode-preference')), findsOneWidget);
    await _fillForm(tester);

    final submit = find.byKey(const Key('enroll-submit'));
    await tester.ensureVisible(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await _tapVisible(tester, find.text('Online'));
    await _tapVisible(tester, find.byKey(const Key('enroll-terms-checkbox')));
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await _tapVisible(tester, submit);
    expect(repo.lastEnrollBatchId, course.batches.first.id);
    expect(repo.lastFormAnswers['delivery_mode_preference'], 'online');
    expect(repo.lastFormAnswers['full_name'], 'Asha Rao');
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline course hides the mode preference', (tester) async {
    final repo = MockCourseRepository();
    final course = _course(CourseMode.offline);
    await tester.pumpWidget(_app(repo, course));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('enroll-mode-preference')), findsNothing);
    expect(find.byKey(const Key('enroll-terms-checkbox')), findsOneWidget);
    await _fillForm(tester);
    await _tapVisible(tester, find.byKey(const Key('enroll-terms-checkbox')));
    await _tapVisible(tester, find.byKey(const Key('enroll-submit')));
    expect(repo.lastEnrollBatchId, course.batches.first.id);
    expect(
      repo.lastFormAnswers.containsKey('delivery_mode_preference'),
      isFalse,
    );
  });

  testWidgets('published custom fields show on enroll', (tester) async {
    final repo = MockCourseRepository();
    final course = _course(CourseMode.offline);
    repo.instituteList = [
      MockCourseRepository.sampleInstitute().copyWith(
        registrationForm: const ConfigurableFormSchema(
          status: 'published',
          publishedFields: [
            ConfigurableFieldDefinition(
              key: 'full_name',
              label: 'Full Name',
              type: ConfigurableFieldType.text,
              required: true,
            ),
            ConfigurableFieldDefinition(
              key: 'custom_school',
              label: 'School name',
              type: ConfigurableFieldType.text,
              required: true,
              custom: true,
              displayOrder: 1,
            ),
          ],
        ),
      ),
    ];
    await tester.pumpWidget(_app(repo, course));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('enroll-field-custom_school')), findsOneWidget);
    expect(find.text('School name *'), findsOneWidget);
    expect(find.text('Aadhaar Number'), findsNothing);
  });

  testWidgets('registration fields stay readable on the dark class feed', (
    tester,
  ) async {
    final repo = MockCourseRepository();
    final course = _course(CourseMode.offline);
    final brokenDark = ThemeData.light().copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C3AED),
        brightness: Brightness.dark,
        surface: const Color(0xFF070B14),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: brokenDark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showClassEnrollmentSheet(
                    context,
                    course: course,
                    batch: course.batches.first,
                    isTrial: false,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Full Name *'), findsOneWidget);
    final theme = Theme.of(
      tester.element(find.byKey(const Key('enroll-registration-form'))),
    );
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.surface, Colors.white);
    expect(
      theme.textTheme.bodyLarge!.color!.computeLuminance(),
      lessThan(0.5),
    );
  });
}
