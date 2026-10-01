import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/domain/class_category_filter.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/domain/education_category.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/screens/courses_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_course_repository.dart';

CourseBatch _batch(
  String id, {
  String slug = '',
  int capacity = 20,
  int enrolled = 0,
  bool admissionsOpen = true,
  CourseMode? mode,
}) => CourseBatch(
  id: id,
  courseId: 'x',
  label: 'Batch $id',
  startsOn: DateTime.now().add(const Duration(days: 3)),
  capacity: capacity,
  enrolledCount: enrolled,
  categorySlug: slug,
  admissionsOpen: admissionsOpen,
  mode: mode,
);

Course _course(
  String id,
  String title, {
  String categoryId = '',
  CourseMode mode = CourseMode.offline,
  List<CourseBatch> batches = const [],
}) => Course(
  id: id,
  instituteId: 'i1',
  title: title,
  description: '',
  mode: mode,
  durationWeeks: 4,
  feeAmount: 1000,
  status: 'published',
  categoryId: categoryId,
  batches: batches,
  instituteName: 'Inst',
);

final _dance = _course(
  'd1',
  'Salsa Nights',
  categoryId: 'dance',
  batches: [
    _batch('d-a', slug: 'dance'),
    _batch('d-b'),
  ],
);
final _code = _course(
  'c1',
  'Python for kids',
  mode: CourseMode.online,
  batches: [_batch('c-a', slug: 'tech_coding', capacity: 5, enrolled: 5)],
);
final _music = _course(
  'm1',
  'Guitar basics',
  mode: CourseMode.hybrid,
  batches: [_batch('m-a', slug: 'music_arts')],
);

void main() {
  group('ClassCategoryFilter', () {
    test('batchCounts counts active batches per category', () {
      final counts = ClassCategoryFilter.batchCounts([_dance, _code, _music]);
      expect(counts[EducationCategory.dance], 2);
      expect(counts[EducationCategory.techCoding], 1);
      expect(counts[EducationCategory.musicArts], 1);
      expect(counts[EducationCategory.academics], 0);
      expect(counts.containsKey(EducationCategory.all), isFalse);
    });

    test('multi-select matches any selected category', () {
      const filter = ClassCategoryFilter(
        categories: {EducationCategory.dance, EducationCategory.musicArts},
      );
      final kept = [_dance, _code, _music].where(filter.matchesCourse);
      expect(kept.map((c) => c.id), ['d1', 'm1']);
    });

    test('empty selection keeps everything; select/clear all', () {
      const filter = ClassCategoryFilter();
      expect([_dance, _code, _music].where(filter.matchesCourse).length, 3);
      final all = filter.selectAll();
      expect(all.categories.length, ClassCategoryFilter.selectable.length);
      expect(all.clearAll().categories, isEmpty);
      expect(filter.toggle(EducationCategory.dance).categories, {
        EducationCategory.dance,
      });
      expect(
        filter
            .toggle(EducationCategory.dance)
            .toggle(EducationCategory.dance)
            .categories,
        isEmpty,
      );
    });

    test('delivery mode restricts courses and batches', () {
      const filter = ClassCategoryFilter(mode: CourseMode.online);
      expect(
        [_dance, _code, _music].where(filter.matchesCourse).single.id,
        'c1',
      );
      expect(filter.matchesBatch(_dance, _dance.batches.first), isFalse);
    });

    test('excluding full & upcoming hides waitlist-only batches', () {
      const filter = ClassCategoryFilter(includeFullAndUpcoming: false);
      expect(filter.matchesBatch(_code, _code.batches.first), isFalse);
      expect(filter.matchesCourse(_code), isFalse);
      expect(filter.matchesCourse(_dance), isTrue);
      final closed = _batch('z', admissionsOpen: false);
      expect(filter.matchesBatch(_dance, closed), isFalse);
      expect(
        const ClassCategoryFilter().matchesBatch(_code, _code.batches.first),
        isTrue,
      );
    });
  });

  group('CoursesListScreen filter sheet', () {
    Widget app(MockCourseRepository repo) => ProviderScope(
      overrides: [
        courseRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(
            initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
        ),
      ],
      child: const MaterialApp(
        home: CoursesListScreen(),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    testWidgets('multi-selects categories with batch counts', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = MockCourseRepository()..courses = [_dance, _code, _music];
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.text('Courses (3)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('courses-filter-button')));
      await tester.pumpAndSettle();
      expect(find.text('2 batches'), findsOneWidget);
      expect(find.text('0 of 6 selected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('class-filter-category-dance')));
      await tester.tap(
        find.byKey(const Key('class-filter-category-music_arts')),
      );
      await tester.pump();
      expect(find.text('2 of 6 selected'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('class-filter-apply')));
      await tester.tap(find.byKey(const Key('class-filter-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Courses (2)'), findsOneWidget);
      expect(find.text('Python for kids'), findsNothing);

      // Single chip still works and replaces the multi selection.
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.text('Courses (3)'), findsOneWidget);
    });

    testWidgets('select all / clear all and waitlist toggle', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = MockCourseRepository()..courses = [_dance, _code, _music];
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('courses-filter-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('class-filter-select-all')));
      await tester.pump();
      expect(find.text('6 of 6 selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('class-filter-clear-all')));
      await tester.pump();
      expect(find.text('0 of 6 selected'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('class-filter-include-full')),
      );
      await tester.tap(find.byKey(const Key('class-filter-include-full')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('class-filter-apply')));
      await tester.tap(find.byKey(const Key('class-filter-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Courses (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
