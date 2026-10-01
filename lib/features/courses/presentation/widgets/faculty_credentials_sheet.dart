import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/course.dart';
import 'academic_sheet.dart';
import 'class_enrollment_sheet.dart';
import 'register_demo_sheet.dart';

/// Faculty portfolio. Opens from a class card on every platform.
Future<void> showFacultyCredentialsSheet(
  BuildContext context, {
  required Course course,
  CourseFaculty? faculty,
  CourseBatch? batch,
}) {
  final opener = context;
  return showAcademicSheet<void>(
    context,
    child: _FacultyCredentials(
      course: course,
      faculty: faculty,
      batch: batch,
      opener: opener,
    ),
  );
}

class _FacultyCredentials extends StatelessWidget {
  const _FacultyCredentials({
    required this.course,
    required this.faculty,
    required this.batch,
    required this.opener,
  });

  final Course course;
  final CourseFaculty? faculty;
  final CourseBatch? batch;
  final BuildContext opener;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = faculty?.name.isNotEmpty == true
        ? faculty!.name
        : course.instructorName;
    final designation = faculty == null
        ? ''
        : (faculty!.designation.isNotEmpty
            ? faculty!.designation
            : faculty!.role);
    final photo = faculty?.photoUrl ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Photo(url: photo, name: name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Faculty' : name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (designation.isNotEmpty)
                    Text(designation, style: theme.textTheme.bodyMedium),
                  if (course.instituteName.isNotEmpty)
                    Text(
                      course.instituteName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (faculty != null && faculty!.experienceText.isNotEmpty)
              _Metric(label: 'Experience', value: faculty!.experienceText),
            if (faculty?.studentsTrained != null)
              _Metric(
                label: 'Students trained',
                value: '${faculty!.studentsTrained}',
              ),
            if (faculty != null && faculty!.qualification.isNotEmpty)
              _Metric(label: 'Qualification', value: faculty!.qualification),
          ],
        ),
        if (faculty != null && faculty!.bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(title: 'Background', body: faculty!.bio),
        ],
        if (faculty != null && faculty!.certifications.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Certifications',
            body: faculty!.certifications.join('\n'),
          ),
        ],
        if (faculty != null && faculty!.achievements.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Achievements',
            body: faculty!.achievements.join('\n'),
          ),
        ],
        if (faculty != null && faculty!.teachingPhilosophy.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Teaching philosophy',
            body: faculty!.teachingPhilosophy,
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (faculty != null && faculty!.id.isNotEmpty)
              OutlinedButton(
                key: const Key('faculty-view-batches'),
                onPressed: () {
                  final id = faculty!.id;
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push(
                    AppRoutes.instructorProfile.replaceAll(':id', id),
                  );
                },
                child: const Text('View all batches'),
              ),
            FilledButton(
              key: const Key('faculty-book-demo'),
              onPressed: () {
                if (!course.hasDemo) return;
                showAfterAcademicSheet(context, opener, (host) {
                  if (batch != null) {
                    showClassEnrollmentSheet(
                      host,
                      course: course,
                      batch: batch!,
                      isTrial: true,
                    );
                    return;
                  }
                  showRegisterDemoSheet(host, course: course);
                });
              },
              child: const Text('Book consultation / demo'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url, required this.name});

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 36,
      backgroundColor: AppTheme.violet.withValues(alpha: 0.15),
      child: ClipOval(
        child: url.isEmpty
            ? Text(
                initial,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.violet,
                ),
              )
            : AppNetworkImage(url: url, width: 72, height: 72),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(body),
      ],
    );
  }
}
