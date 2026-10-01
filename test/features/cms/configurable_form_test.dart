import 'package:bookmyspace/features/cms/domain/configurable_form.dart';
import 'package:bookmyspace/features/cms/domain/target_modules.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/cms/presentation/widgets/configurable_form_builder.dart';
import 'package:bookmyspace/features/cms/presentation/widgets/configurable_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../courses/mock_course_repository.dart';

void main() {
  test('defaults enable name and mobile, not Aadhaar', () {
    final schema = ConfigurableFormSchema.defaults();
    final keys = schema.activeFields.map((f) => f.key).toSet();
    expect(keys, containsAll(['full_name', 'mobile', 'email']));
    expect(keys.contains('aadhaar'), isFalse);
    expect(keys.contains('aadhaar_upload'), isFalse);
  });

  test('owner can enable a custom field and disable a catalog field', () {
    var schema = ConfigurableFormSchema.defaults();
    final email = schema.editorFields.firstWhere((f) => f.key == 'email');
    schema = schema.copyWith(
      draftFields: [
        for (final field in schema.editorFields)
          if (field.key == 'email') field.copyWith(enabled: false) else field,
        ConfigurableFieldDefinition(
          key: 'custom_blood_group',
          label: 'Blood group',
          type: ConfigurableFieldType.dropdown,
          options: const ['A', 'B', 'O'],
          custom: true,
          enabled: true,
          required: true,
          displayOrder: 99,
        ),
      ],
    );
    final published = schema.publish();
    expect(published.activeFields.any((f) => f.key == 'email'), isFalse);
    expect(
      published.activeFields.any((f) => f.key == 'custom_blood_group'),
      isTrue,
    );
    expect(email.enabled, isTrue);
  });

  test('required field cannot be hidden', () {
    final schema = ConfigurableFormSchema(
      draftFields: [
        const ConfigurableFieldDefinition(
          key: 'full_name',
          label: 'Full Name',
          type: ConfigurableFieldType.text,
          required: true,
          visible: false,
          enabled: true,
        ),
      ],
    );
    expect(schema.setupErrors(), isNotEmpty);
  });

  test('required dropdown needs options', () {
    final schema = ConfigurableFormSchema(
      draftFields: [
        const ConfigurableFieldDefinition(
          key: 'gender',
          label: 'Gender',
          type: ConfigurableFieldType.dropdown,
          required: true,
          enabled: true,
        ),
      ],
    );
    expect(schema.setupErrors().join(' '), contains('option'));
  });

  test('optional field may be empty', () {
    final schema = ConfigurableFormSchema.defaults();
    final errors = schema.validateAnswers({
      'full_name': 'Asha',
      'mobile': '9000000000',
    });
    expect(errors, isEmpty);
  });

  test('Aadhaar disabled strips fields from the live form', () {
    final withAadhaar = ConfigurableFormSchema(
      publishedFields: ConfigurableFormSchema.catalog()
          .map(
            (f) => f.key.startsWith('aadhaar')
                ? f.copyWith(enabled: true, visible: true, required: true)
                : f,
          )
          .toList(),
    );
    expect(withAadhaar.activeFields.any((f) => f.key == 'aadhaar'), isTrue);
    expect(
      withAadhaar.withoutAadhaar().activeFields.any((f) => f.key == 'aadhaar'),
      isFalse,
    );
  });

  test('Aadhaar is masked in public answers', () {
    final split = SensitiveFieldPolicy.split({'aadhaar': '123412341234'});
    expect(split.public['aadhaar'], 'XXXX-XXXX-1234');
    expect(split.sensitive['aadhaar'], '123412341234');
  });

  test('faculty without photo still renders name-only data', () {
    const withPhoto = CourseFaculty(
      id: 'f1',
      courseId: 'c1',
      name: 'Priya',
      photoUrl: 'https://example.com/p.jpg',
    );
    const withoutPhoto = CourseFaculty(
      id: 'f2',
      courseId: 'c1',
      name: 'Ravi',
    );
    expect(withPhoto.photoUrl, isNotEmpty);
    expect(withoutPhoto.photoUrl, isEmpty);
  });

  test('course without demo has no demo methods', () {
    final course = MockCourseRepository.sampleCourse();
    expect(course.hasDemo, isFalse);
    expect(course.demoVideoUrl, isEmpty);
  });

  test('course with demo keeps real URL', () {
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
      demoMethods: const [CourseDemoMethod.uploadedVideo],
      demoVideoUrl: 'https://example.com/demo.mp4',
    );
    expect(course.hasDemo, isTrue);
    expect(course.demoVideoUrl, isNotEmpty);
  });

  test('multiple branches stay independent of online-only', () {
    const a = InstituteBranch(
      id: 'b1',
      instituteId: 'i1',
      name: 'Campus 1',
      city: 'Hyderabad',
    );
    const b = InstituteBranch(
      id: 'b2',
      instituteId: 'i1',
      name: 'Online',
      isOnlineOnly: true,
    );
    expect(a.hasAddress, isTrue);
    expect(a.isOnlineOnly, isFalse);
    expect(b.isOnlineOnly, isTrue);
    expect(b.hasAddress, isFalse);
  });

  test('online-only module hides location when no address', () {
    const modules = TargetModuleConfig({'location': true});
    expect(
      modules.show(key: 'location', hasData: false),
      isFalse,
    );
    expect(
      modules.show(key: 'location', hasData: true),
      isTrue,
    );
    expect(
      const TargetModuleConfig({'location': false})
          .show(key: 'location', hasData: true),
      isFalse,
    );
  });

  test('owner authorization uses the same institute list they own', () async {
    final repo = MockCourseRepository()
      ..instituteList = [
        MockCourseRepository.sampleInstitute(),
        MockCourseRepository.sampleInstitute(id: 'i2'),
      ];
    repo.instituteList[1];
    final mine = await repo.ownerInstitutes();
    expect(mine.map((i) => i.id), containsAll(['i1', 'i2']));
  });

  testWidgets('student form omits Aadhaar when disabled', (tester) async {
    final schema = ConfigurableFormSchema.defaults();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigurableFormFields(
            schema: schema,
            values: const {},
            onChanged: (_, __) {},
          ),
        ),
      ),
    );
    expect(find.text('Full Name *'), findsOneWidget);
    expect(find.text('Aadhaar Number'), findsNothing);
    expect(find.text('Aadhaar upload'), findsNothing);
  });

  testWidgets('student form shows Aadhaar when enabled', (tester) async {
    final schema = ConfigurableFormSchema(
      publishedFields: ConfigurableFormSchema.catalog()
          .map(
            (f) => f.key == 'aadhaar'
                ? f.copyWith(enabled: true, visible: true, required: true)
                : f.key == 'full_name'
                    ? f
                    : f.copyWith(enabled: false),
          )
          .toList(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfigurableFormFields(
            schema: schema,
            values: const {},
            onChanged: (_, __) {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Aadhaar Number'), findsOneWidget);
  });

  testWidgets('owner form builder fits 320 and 1024', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [Size(320, 640), Size(1024, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConfigurableFormBuilder(
                schema: ConfigurableFormSchema.defaults(),
                onChanged: (_) {},
                onPublish: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Publish form'), findsOneWidget);
      expect(find.text('Add custom field'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('dynamic enrollment stores answers on the mock', () async {
    final repo = MockCourseRepository()
      ..courses = [MockCourseRepository.sampleCourse(batchCount: 1)];
    await repo.enroll(
      batchId: 'b0',
      studentName: 'Asha',
      contactPhone: '9000000000',
      formAnswers: {'full_name': 'Asha', 'custom_blood_group': 'O'},
    );
    expect(repo.lastFormAnswers['custom_blood_group'], 'O');
  });

  test('missing optional faculty values stay empty, never N/A', () {
    const faculty = CourseFaculty(id: 'f', courseId: 'c', name: 'Nita');
    expect(faculty.experienceText, isEmpty);
    expect(faculty.qualification, isEmpty);
    expect(faculty.photoUrl, isEmpty);
  });
}
