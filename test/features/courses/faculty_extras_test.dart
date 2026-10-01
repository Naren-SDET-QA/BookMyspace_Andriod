import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/courses/presentation/screens/instructor_profile_screen.dart';
import 'package:bookmyspace/features/courses/presentation/widgets/faculty_editor_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('faculty extras parse from course_faculty columns', () {
    final f = CourseFaculty.fromJson({
      'id': 'f1',
      'course_id': 'c1',
      'name': 'Anita Rao',
      'qualification': 'M.Sc Physics; B.Ed',
      'certifications': ['CTET', ' ', 'Google Educator'],
      'awards': ['Best Teacher 2024'],
      'students_trained': 1200,
      'teaching_philosophy': 'Curiosity first.',
    });
    expect(f.certifications, ['CTET', 'Google Educator']);
    expect(f.achievements, ['Best Teacher 2024']);
    expect(f.studentsTrained, 1200);
    expect(f.teachingPhilosophy, 'Curiosity first.');
    // Real certifications win over the qualification workaround.
    expect(facultyCredentials(f), ['CTET', 'Google Educator']);
  });

  test('without certifications the qualification split still works', () {
    final f = CourseFaculty.fromJson({
      'id': 'f2',
      'course_id': 'c1',
      'name': 'Ravi',
      'qualification': 'M.Tech; GATE AIR 120',
    });
    expect(f.certifications, isEmpty);
    expect(f.studentsTrained, isNull);
    expect(facultyCredentials(f), ['M.Tech', 'GATE AIR 120']);
  });

  test('editor splits one-per-line, else comma/semicolon', () {
    expect(splitEntries('CTET\nNET, JRF\n'), ['CTET', 'NET, JRF']);
    expect(splitEntries('Hindi, English; Telugu'), ['Hindi', 'English', 'Telugu']);
    expect(splitEntries('  '), isEmpty);
  });
}
