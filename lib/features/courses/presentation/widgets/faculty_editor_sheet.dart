import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/course.dart';
import '../../infrastructure/faculty_profile_writer.dart';
import '../course_providers.dart';

/// Owner editor for an existing instructor: profile, certifications,
/// achievements, students trained and teaching philosophy.
Future<bool?> showFacultyEditorSheet(
  BuildContext context,
  CourseFaculty faculty,
) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _FacultyEditor(faculty: faculty),
    ),
  );
}

/// Splits editor text into entries: one per line when there are several
/// lines, otherwise on commas or semicolons.
List<String> splitEntries(String text) {
  final byLine = text.split('\n');
  final parts = byLine.length > 1 ? byLine : text.split(RegExp(r'[;,]'));
  return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
}

class _FacultyEditor extends ConsumerStatefulWidget {
  const _FacultyEditor({required this.faculty});

  final CourseFaculty faculty;

  @override
  ConsumerState<_FacultyEditor> createState() => _FacultyEditorState();
}

class _FacultyEditorState extends ConsumerState<_FacultyEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = widget.faculty;
    _c = {
      'name': TextEditingController(text: f.name),
      'designation': TextEditingController(
        text: f.designation.isNotEmpty ? f.designation : f.role,
      ),
      'qualification': TextEditingController(text: f.qualification),
      'specialization': TextEditingController(text: f.specialization),
      'experience': TextEditingController(text: f.experienceText),
      'students': TextEditingController(
        text: f.studentsTrained?.toString() ?? '',
      ),
      'bio': TextEditingController(text: f.bio),
      'philosophy': TextEditingController(text: f.teachingPhilosophy),
      'certifications': TextEditingController(
        text: f.certifications.join('\n'),
      ),
      'achievements': TextEditingController(text: f.achievements.join('\n')),
      'skills': TextEditingController(text: f.skills.join(', ')),
      'languages': TextEditingController(text: f.languages.join(', ')),
      'demo': TextEditingController(text: f.demoUrl),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final f = widget.faculty;
    final updated = CourseFaculty(
      id: f.id,
      courseId: f.courseId,
      instituteId: f.instituteId,
      name: _c['name']!.text.trim(),
      role: f.role,
      designation: _c['designation']!.text.trim(),
      department: f.department,
      qualification: _c['qualification']!.text.trim(),
      specialization: _c['specialization']!.text.trim(),
      experienceText: _c['experience']!.text.trim(),
      bio: _c['bio']!.text.trim(),
      photoUrl: f.photoUrl,
      demoUrl: _c['demo']!.text.trim(),
      resumeUrl: f.resumeUrl,
      isActive: f.isActive,
      skills: splitEntries(_c['skills']!.text),
      languages: splitEntries(_c['languages']!.text),
      certifications: splitEntries(_c['certifications']!.text),
      achievements: splitEntries(_c['achievements']!.text),
      studentsTrained: int.tryParse(_c['students']!.text.trim()),
      teachingPhilosophy: _c['philosophy']!.text.trim(),
    );
    try {
      await ref.read(facultyProfileWriterProvider).update(updated);
      ref.invalidate(ownerCoursesProvider);
      ref.invalidate(publishedCoursesProvider);
      if (f.courseId.isNotEmpty) {
        ref.invalidate(courseDetailProvider(f.courseId));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Widget _field(
    String key,
    String label, {
    int maxLines = 1,
    String? helper,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: Key('faculty-edit-$key'),
          controller: _c[key],
          maxLines: maxLines,
          keyboardType: keyboard,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('Edit Instructor',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _field(
              'name',
              'Name',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Name is required' : null,
            ),
            _field('designation', 'Designation'),
            _field('qualification', 'Qualification'),
            _field('specialization', 'Specialization'),
            _field('experience', 'Experience (e.g. 8+ years)'),
            _field(
              'students',
              'Students trained',
              keyboard: TextInputType.number,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = int.tryParse(t);
                return n == null || n < 0 ? 'Enter a whole number' : null;
              },
            ),
            _field('bio', 'Biography', maxLines: 4),
            _field('philosophy', 'Teaching philosophy', maxLines: 3),
            _field(
              'certifications',
              'Certifications',
              maxLines: 4,
              helper: 'One per line',
            ),
            _field(
              'achievements',
              'Achievements & awards',
              maxLines: 4,
              helper: 'One per line',
            ),
            _field('skills', 'Skills', helper: 'Comma separated'),
            _field('languages', 'Languages', helper: 'Comma separated'),
            _field('demo', 'Demo video URL', keyboard: TextInputType.url),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              key: const Key('faculty-edit-save'),
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
