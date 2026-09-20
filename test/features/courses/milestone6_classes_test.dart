import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/domain/education_category.dart';
import 'package:bookmyspace/features/search/domain/voice_filter_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_course_repository.dart';

void main() {
  test('education categories match titles and slugs', () {
    expect(
      EducationCategory.techCoding.matches(
        title: 'Flutter App Development Bootcamp',
        subject: '',
        categorySlug: '',
        instructor: '',
      ),
      isTrue,
    );
    expect(
      EducationCategory.dance.matches(
        title: 'Kathak Foundation',
        subject: 'dance',
        categorySlug: 'dance',
        instructor: '',
      ),
      isTrue,
    );
    expect(
      EducationCategory.fromSlug('sports_fitness'),
      EducationCategory.sportsFitness,
    );
  });

  test('voice parser routes coaching keywords to institutes_classes', () {
    for (final phrase in [
      'coaching classes in hyderabad',
      'coding bootcamp near me',
      'badminton training academy',
      'dance class',
    ]) {
      final result = VoiceCommandFilterParser.parse(phrase);
      expect(result.categorySlug, 'institutes_classes', reason: phrase);
      expect(result.isEducationIntent, isTrue);
    }
  });

  test('capacity-safe mock enroll increments then can drop', () async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse(batchCount: 1)];
    final before = repo.courses.first.batches.first.enrolledCount;
    final record = await repo.enroll(
      batchId: 'b0',
      studentName: 'Asha',
      contactPhone: '9000000000',
    );
    expect(record.status, 'enrolled');
    expect(record.admissionCode, isNotEmpty);
    expect(repo.courses.first.batches.first.enrolledCount, before + 1);

    final trial = await repo.enroll(batchId: 'b0', isTrial: true);
    expect(trial.isTrial, isTrue);
  });

  test('batch ongoing and seat helpers use live counts', () {
    final batch = CourseBatch(
      id: 'b',
      courseId: 'c',
      label: 'Morning',
      startsOn: DateTime.now().subtract(const Duration(days: 1)),
      endsOn: DateTime.now().add(const Duration(days: 10)),
      capacity: 30,
      enrolledCount: 24,
      waitlistEnabled: true,
    );
    expect(batch.seatsLeft, 6);
    expect(batch.isFull, isFalse);
    expect(batch.isOngoingToday, isTrue);
  });
}
