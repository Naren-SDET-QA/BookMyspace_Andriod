import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:flutter_test/flutter_test.dart';

CourseBatch batch({
  required DateTime startsOn,
  DateTime? endsOn,
  DateTime? createdAt,
  List<int> days = const [],
}) =>
    CourseBatch(
      id: 'b',
      courseId: 'c',
      label: 'Morning',
      startsOn: startsOn,
      endsOn: endsOn,
      capacity: 10,
      enrolledCount: 0,
      createdAt: createdAt,
      daysOfWeek: days,
    );

void main() {
  // Wednesday 2026-09-30, 10:00.
  final now = DateTime(2026, 9, 30, 10);

  test('future start is upcoming', () {
    expect(
      batch(startsOn: DateTime(2026, 10, 5)).highlightOn(now),
      BatchHighlight.upcoming,
    );
  });

  test('running batch on a class day is live today', () {
    final b = batch(
      startsOn: DateTime(2026, 9, 1),
      endsOn: DateTime(2026, 12, 1),
      days: const [1, 3, 5],
    );
    expect(b.highlightOn(now), BatchHighlight.liveToday);
    expect(b.daysLabel, 'Mon · Wed · Fri');
  });

  test('not a class day and recently created is new', () {
    final b = batch(
      startsOn: DateTime(2026, 9, 1),
      days: const [2, 4],
      createdAt: now.subtract(const Duration(days: 3)),
    );
    expect(b.highlightOn(now), BatchHighlight.isNew);
  });

  test('finished batch has no highlight', () {
    final b = batch(
      startsOn: DateTime(2026, 6, 1),
      endsOn: DateTime(2026, 8, 1),
      createdAt: DateTime(2026, 5, 1),
    );
    expect(b.highlightOn(now), isNull);
  });

  test('parses highlight columns', () {
    final b = CourseBatch.fromJson({
      'id': 'b1',
      'course_id': 'c1',
      'label': 'Evening',
      'starts_on': '2026-09-01',
      'capacity': 20,
      'enrolled_count': 5,
      'todays_topic': 'Newton laws',
      'highlight_tag': 'Olympiad prep',
      'days_of_week': [6, 7, 9],
      'age_group': '12-15 years',
      'skill_level': 'advanced',
    });
    expect(b.todaysTopic, 'Newton laws');
    expect(b.daysOfWeek, [6, 7]);
    expect(b.daysLabel, 'Sat · Sun');
    expect(b.skillLevelLabel, 'Advanced');
  });
}
