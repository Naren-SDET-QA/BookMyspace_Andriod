import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/course.dart';
import '../course_providers.dart';
import '../widgets/course_spec_card.dart';
import '../widgets/external_link.dart';

/// The profile behind a course's faculty card, plus every batch this
/// instructor currently teaches.
@immutable
class InstructorProfile {
  const InstructorProfile({required this.faculty, required this.courses});

  final CourseFaculty faculty;

  /// Published courses this instructor teaches (same faculty row id, or the
  /// same name at the same institute).
  final List<Course> courses;
}

/// Finds [facultyId] across [courses] and gathers all of their courses.
InstructorProfile? findInstructorProfile(
  List<Course> courses,
  String facultyId,
) {
  CourseFaculty? faculty;
  for (final c in courses) {
    faculty = c.faculty.where((f) => f.id == facultyId).firstOrNull;
    if (faculty != null) break;
  }
  if (faculty == null) return null;
  final name = faculty.name.trim().toLowerCase();
  final taught = courses.where((c) {
    return c.faculty.any((f) {
      if (f.id == facultyId) return true;
      final sameInstitute =
          faculty!.instituteId.isEmpty ||
          f.instituteId.isEmpty ||
          f.instituteId == faculty.instituteId;
      return f.isActive && sameInstitute && f.name.trim().toLowerCase() == name;
    });
  }).toList();
  return InstructorProfile(faculty: faculty, courses: taught);
}

class InstructorProfileScreen extends ConsumerWidget {
  const InstructorProfileScreen({super.key, required this.facultyId});

  final String facultyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(publishedCoursesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.school_rounded,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Faculty Profile & Portfolio',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Verified Instructor Credentials',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('instructor-close'),
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.home),
          ),
        ],
      ),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(publishedCoursesProvider),
        ),
        data: (courses) {
          final profile = findInstructorProfile(courses, facultyId);
          if (profile == null) {
            return const EmptyState(
              icon: Icons.person_search_rounded,
              title: 'Instructor not found',
              message: 'This profile is no longer available.',
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _ProfileBody(profile: profile),
            ),
          );
        },
      ),
    );
  }
}

/// "14+ years of coaching" -> "14+ Yrs"; empty when no number is present.
String experienceBadge(String text) {
  final m = RegExp(r'(\d+\+?)').firstMatch(text);
  return m == null ? '' : '${m.group(1)} Yrs';
}

/// Splits a "Teaching philosophy:" / "Philosophy:" line out of a bio.
({String bio, String philosophy}) splitPhilosophy(String bio) {
  final m = RegExp(
    r'(?:teaching\s+)?philosophy\s*[:\-]\s*(.+)$',
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  ).firstMatch(bio);
  if (m == null) return (bio: bio.trim(), philosophy: '');
  final quote = m.group(1)!.trim().replaceAll(RegExp(r'^["“]|["”]$'), '');
  return (bio: bio.substring(0, m.start).trim(), philosophy: quote.trim());
}

/// Credentials shown in "Official Certifications & Credentials": the
/// qualification and specialization, split on `;`, `|` or new lines.
List<String> facultyCredentials(CourseFaculty f) {
  if (f.certifications.isNotEmpty) return f.certifications.toSet().toList();
  final parts = <String>[];
  for (final raw in [f.qualification, f.specialization]) {
    parts.addAll(
      raw
          .split(RegExp(r'[;|\n]+'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty),
    );
  }
  return parts.toSet().toList();
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final InstructorProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final f = profile.faculty;
    final instituteId = f.instituteId.isNotEmpty
        ? f.instituteId
        : profile.courses.map((c) => c.instituteId).firstOrNull ?? '';
    final institute = instituteId.isEmpty
        ? null
        : ref.watch(instituteDetailProvider(instituteId)).valueOrNull;
    final phone =
        profile.courses
            .map((c) => c.contactPhone)
            .where((p) => p.trim().isNotEmpty)
            .firstOrNull ??
        institute?.phone ??
        '';
    final whatsapp = institute?.whatsapp ?? '';

    final ratings = <double>[
      for (final c in profile.courses)
        ...?ref
            .watch(courseFeedbackProvider(c.id))
            .valueOrNull
            ?.map((e) => e.rating.toDouble()),
    ];
    final rating = ratings.isEmpty
        ? ''
        : (ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(2);
    final enrolled = profile.courses
        .expand((c) => c.batches)
        .fold<int>(0, (sum, b) => sum + b.enrolledCount);
    // Institute-entered lifetime total wins over current enrollments.
    final students = (f.studentsTrained ?? 0) > enrolled
        ? f.studentsTrained!
        : enrolled;
    final batchCount = profile.courses
        .expand((c) => c.batches)
        .where((b) => b.isActive)
        .length;
    final exp = experienceBadge(f.experienceText);
    final parsed = splitPhilosophy(f.bio);
    final split = f.teachingPhilosophy.trim().isNotEmpty
        ? (bio: f.bio.trim(), philosophy: f.teachingPhilosophy.trim())
        : parsed;
    final credentials = facultyCredentials(f);
    final designation = f.designation.isNotEmpty ? f.designation : f.role;
    final qualificationLine = [
      if (f.department.isNotEmpty) f.department,
      if (credentials.isNotEmpty) credentials.first,
    ].join(' · ');
    final accent = theme.colorScheme.primary;

    Widget stat(IconData icon, String value, String label, String key) =>
        Expanded(
          key: Key(key),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: const Color(0xFFFDE68A)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

    return ListView(
      key: const Key('instructor-profile'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        // Hero card: avatar, name, designation, credentials, stats.
        Container(
          key: const Key('instructor-hero'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF312E81), Color(0xFF4338CA)],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFA5B4FC),
                            width: 3,
                          ),
                        ),
                        child: FacultyAvatar(faculty: f, radius: 40),
                      ),
                      if (credentials.isNotEmpty)
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Color(0xFF6366F1),
                            child: Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (designation.isNotEmpty)
                          Text(
                            designation,
                            style: const TextStyle(
                              color: Color(0xFFA5B4FC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (qualificationLine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              qualificationLine,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 28),
              Row(
                children: [
                  stat(
                    Icons.workspace_premium_rounded,
                    exp.isEmpty ? '—' : exp,
                    'EXPERIENCE',
                    'stat-experience',
                  ),
                  stat(
                    Icons.groups_rounded,
                    students > 0 ? '$students+' : '—',
                    'STUDENTS',
                    'stat-students',
                  ),
                  stat(
                    Icons.star_rounded,
                    rating.isEmpty ? 'New' : rating,
                    'RATING',
                    'stat-rating',
                  ),
                  stat(
                    Icons.class_rounded,
                    '$batchCount ${batchCount == 1 ? 'Batch' : 'Batches'}',
                    'COURSES',
                    'stat-batches',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('instructor-call'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9F1239),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: phone.trim().isEmpty
                    ? null
                    : () => openContactLink(phone),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call Desk'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('instructor-whatsapp'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: whatsapp.trim().isEmpty
                    ? null
                    : () => openWhatsApp(whatsapp),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              ),
            ),
          ],
        ),
        if (split.bio.isNotEmpty || split.philosophy.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Heading('Biography & Background', color: accent),
          const SizedBox(height: 10),
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (split.bio.isNotEmpty)
                  Text(split.bio, style: theme.textTheme.bodyMedium),
                if (split.philosophy.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('instructor-philosophy'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9F1239).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF9F1239).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              size: 18,
                              color: Color(0xFFE11D48),
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'TEACHING PHILOSOPHY',
                                style: TextStyle(
                                  color: Color(0xFFE11D48),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '"${split.philosophy}"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (credentials.isNotEmpty || f.resumeUrl.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _Heading(
                  'Official Certifications & Credentials',
                  color: accent,
                ),
              ),
              if (credentials.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${credentials.length} Verified',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final c in credentials)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Section(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0x33F59E0B),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 18,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Color(0xFF22C55E),
                    ),
                  ],
                ),
              ),
            ),
          if (f.resumeUrl.isNotEmpty)
            OutlinedButton.icon(
              key: const Key('instructor-certificates'),
              onPressed: () => openMediaUrl(f.resumeUrl),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('View certificates & resume'),
            ),
        ],
        if (f.achievements.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Heading('Achievements & Awards', color: accent),
          const SizedBox(height: 10),
          for (final a in f.achievements)
            Padding(
              key: Key('instructor-achievement-$a'),
              padding: const EdgeInsets.only(bottom: 8),
              child: _Section(
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        a,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (f.skills.isNotEmpty || f.languages.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Heading('Skills & Languages', color: accent),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in f.skills) Chip(label: Text(s)),
              for (final l in f.languages)
                Chip(
                  avatar: const Icon(Icons.translate_rounded, size: 16),
                  label: Text(l),
                ),
            ],
          ),
        ],
        if (f.demoUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('instructor-demo'),
            onPressed: () => openMediaUrl(f.demoUrl),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Watch demo class'),
          ),
        ],
        const SizedBox(height: 22),
        _Heading('All Batches (${profile.courses.length})', color: accent),
        const SizedBox(height: 10),
        for (final c in profile.courses) _CourseBatchCard(course: c),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _CourseBatchCard extends StatelessWidget {
  const _CourseBatchCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batches = course.batches.where((b) => b.isActive).toList();
    final date = DateFormat('d MMM');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('instructor-course-${course.id}'),
        onTap: () =>
            context.push(AppRoutes.courseDetails.replaceAll(':id', course.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              if (course.durationWeeks > 0)
                Text(
                  courseDurationLabel(course.durationWeeks),
                  style: theme.textTheme.bodySmall,
                ),
              for (final b in batches)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            b.label,
                            if (b.timing.isNotEmpty) b.timing,
                            'from ${date.format(b.startsOn)}',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        b.capacity <= 0
                            ? ''
                            : b.seatsLeft <= 0
                            ? 'Full'
                            : '${b.seatsLeft} left',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: b.seatsLeft <= 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
