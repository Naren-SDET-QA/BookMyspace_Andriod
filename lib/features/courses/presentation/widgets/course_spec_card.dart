import 'package:flutter/material.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../domain/course.dart';

/// Picks the batch a learner most likely cares about: the first active batch
/// that has not ended, else the first batch.
CourseBatch? primaryBatch(Course course) {
  final today = DateUtils.dateOnly(DateTime.now());
  for (final b in course.batches) {
    if (!b.isActive) continue;
    final end = b.endsOn == null ? null : DateUtils.dateOnly(b.endsOn!);
    if (end == null || !end.isBefore(today)) return b;
  }
  return course.batches.isEmpty ? null : course.batches.first;
}

/// "3 Months" for multiples of ~4 weeks, else "N weeks".
String courseDurationLabel(int weeks) {
  if (weeks <= 0) return '';
  if (weeks % 4 == 0) {
    final months = weeks ~/ 4;
    return months == 1 ? '1 Month' : '$months Months';
  }
  return weeks == 1 ? '1 week' : '$weeks weeks';
}

/// "sports_fitness" -> "Sports & Fitness".
String humanizeSlug(String slug) {
  final words = slug
      .split(RegExp(r'[_\-\s]+'))
      .where((w) => w.isNotEmpty && w != 'and')
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .toList();
  if (words.length == 2) return '${words[0]} & ${words[1]}';
  return words.join(' ');
}

/// "FACULTY & BATCH SPECIFICATIONS" card on the course page. Every row is
/// optional and only shown when the course/batch/institute has that data.
class CourseSpecCard extends StatelessWidget {
  const CourseSpecCard({
    super.key,
    required this.course,
    this.campusLocation = '',
  });

  final Course course;

  /// Branch/institute address, resolved by the caller.
  final String campusLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = primaryBatch(course);
    final lead = course.faculty.where((f) => f.isActive).firstOrNull;
    final facultyName = lead == null
        ? course.instructorName
        : [
            lead.name,
            if (lead.designation.isNotEmpty)
              '(${lead.designation})'
            else if (lead.role.isNotEmpty)
              '(${lead.role})',
          ].join(' ');
    final qualification = lead == null
        ? ''
        : [
            if (lead.qualification.isNotEmpty) lead.qualification,
            if (lead.experienceText.isNotEmpty) lead.experienceText,
          ].join(' • ');
    final timings = [
      if (batch != null && batch.timing.trim().isNotEmpty) batch.timing.trim(),
      if (course.scheduleNotes.trim().isNotEmpty) course.scheduleNotes.trim(),
    ].join(' · ');
    final seats = batch == null || batch.capacity <= 0
        ? ''
        : batch.seatsLeft <= 0
        ? 'Full (Total: ${batch.capacity})'
        : '${batch.seatsLeft} seats left (Total: ${batch.capacity})';

    final rows = <(IconData, String, String, String)>[
      if (facultyName.trim().isNotEmpty)
        (Icons.person_rounded, 'Faculty Name', facultyName, 'spec-faculty'),
      if (qualification.isNotEmpty)
        (
          Icons.verified_rounded,
          'Qualification & Exp',
          qualification,
          'spec-qualification',
        ),
      if (timings.isNotEmpty)
        (Icons.schedule_rounded, 'Class Timings', timings, 'spec-timings'),
      if (course.durationWeeks > 0)
        (
          Icons.hourglass_bottom_rounded,
          'Course Duration',
          courseDurationLabel(course.durationWeeks),
          'spec-duration',
        ),
      if (campusLocation.trim().isNotEmpty)
        (
          Icons.location_on_rounded,
          'Campus Location',
          campusLocation.trim(),
          'spec-location',
        ),
      if (seats.isNotEmpty)
        (Icons.groups_rounded, 'Batch Seats Available', seats, 'spec-seats'),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final accent = theme.colorScheme.primary;
    return Container(
      key: const Key('course-spec-card'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FACULTY & BATCH SPECIFICATIONS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          for (final (icon, label, value, key) in rows)
            Padding(
              key: Key(key),
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Icon(icon, size: 20, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Instructor Portfolio & Bio" link card for one faculty member.
class InstructorPortfolioCard extends StatelessWidget {
  const InstructorPortfolioCard({
    super.key,
    required this.faculty,
    required this.onTap,
  });

  final CourseFaculty faculty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF);
    final fg = isDark ? Colors.white : const Color(0xFF1E1B4B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('instructor-card-${faculty.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FacultyAvatar(faculty: faculty, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructor Portfolio & Bio',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark
                              ? const Color(0xFFA5B4FC)
                              : const Color(0xFF4F46E5),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "View ${faculty.name}'s Certifications, Bio & All "
                        'Batches →',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FacultyAvatar extends StatelessWidget {
  const FacultyAvatar({super.key, required this.faculty, this.radius = 24});

  final CourseFaculty faculty;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = faculty.name.trim().isEmpty
        ? '?'
        : faculty.name.trim()[0].toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: faculty.photoUrl.isNotEmpty
            ? AppNetworkImage(url: faculty.photoUrl, fit: BoxFit.cover)
            : ColoredBox(
                color: theme.colorScheme.primaryContainer,
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: radius * 0.8,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Human-readable campus address: the primary active branch first, then any
/// active branch with an address, then the institute's own address/city.
String campusLocationLabel({
  List<InstituteBranch> branches = const [],
  Institute? institute,
  String fallbackCity = '',
}) {
  String join(List<String> parts) =>
      parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toSet().join(', ');

  final active = branches.where((b) => b.isActive && !b.isOnlineOnly);
  final branch =
      active.where((b) => b.isPrimary && b.hasAddress).firstOrNull ??
      active.where((b) => b.hasAddress).firstOrNull;
  if (branch != null) {
    return join([branch.address, branch.landmark, branch.city]);
  }
  if (institute != null && institute.hasLocation) {
    return join([institute.address, institute.city]);
  }
  return fallbackCity.trim();
}

/// Category chip label for a course: batch category slug, else subject.
String courseCategoryLabel(Course course) {
  final batch = primaryBatch(course);
  if (batch == null) return '';
  if (batch.categorySlug.trim().isNotEmpty) {
    return humanizeSlug(batch.categorySlug.trim());
  }
  return batch.subject.trim();
}
