import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';
import '../../domain/education_category.dart';
import 'batch_class_card.dart';
import 'course_spec_card.dart';
import 'external_link.dart';

/// A tappable course card used in every course listing.
///
/// Courses with a batch render the full [BatchClassCard] — the same class
/// card used by the education hub — so all course feeds share one design.
/// A course that has no batch yet falls back to [CourseOnlyClassCard],
/// which uses the identical visual language with course-level data.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final batch = primaryBatch(course);
    if (batch != null) {
      return BatchClassCard(
        course: course,
        batch: batch,
        onOpen: () => context.push(
          AppRoutes.courseDetails.replaceAll(':id', course.id),
        ),
      );
    }
    return CourseOnlyClassCard(course: course);
  }
}

/// Same layout as [BatchClassCard] but driven entirely by [Course] fields,
/// for courses that have not been given a batch yet.
class CourseOnlyClassCard extends StatelessWidget {
  const CourseOnlyClassCard({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final lead = classFacultyLead(course);
    final faculty = lead.faculty;
    final category = EducationCategory.fromSlug(course.categoryId);
    final duration = classDurationLabel(course.durationWeeks);
    final schedule = course.scheduleNotes.trim();
    final place = course.instituteCity;
    final phone = course.contactPhone;
    final shown = course.payableAmount;
    final offPercent = course.feeAmount > 0 && course.discountAmount > 0
        ? ((course.discountAmount / course.feeAmount) * 100).round()
        : 0;

    void openCourse() => context.push(
          AppRoutes.courseDetails.replaceAll(':id', course.id),
        );

    return Container(
      key: Key('course-card-${course.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFF101628),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF243049)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CourseCover(course: course, category: category),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: openCourse,
                  child: Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (course.instituteName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2366),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 16,
                          color: Color(0xFFC4B5FD),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            course.instituteName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (course.instituteVerified)
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Color(0xFF34D399),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ClassTimingPanel(
                  timing: schedule.isNotEmpty
                      ? schedule
                      : 'Schedule announced per batch',
                  duration: duration,
                ),
                if (lead.name.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClassFacultyPanel(
                    batchId: course.id,
                    name: lead.name,
                    photoUrl: faculty?.photoUrl ?? '',
                    experience: faculty?.experienceText ?? '',
                    credentialLine: lead.credentials,
                    onTap: openCourse,
                  ),
                ],
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.near_me_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: course.isFree ? 'Free' : formatInr(shown),
                            style: const TextStyle(
                              color: Color(0xFFC4B5FD),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (offPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9F1239),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$offPercent% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ClassRoundAction(
                      icon: Icons.call_rounded,
                      color: const Color(0xFF4C1D95),
                      iconColor: const Color(0xFFE9D5FF),
                      onTap: () => _dial(context, phone, openContactLink,
                          'Calls are not available here.'),
                    ),
                    ClassRoundAction(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF14532D),
                      iconColor: const Color(0xFF86EFAC),
                      onTap: () => _dial(context, phone, openWhatsApp,
                          'WhatsApp is not available on this device.'),
                    ),
                    FilledButton.icon(
                      onPressed: openCourse,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.school_rounded, size: 16),
                      label: const Text(
                        'View Course',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _dial(
    BuildContext context,
    String phone,
    Future<bool> Function(String) open,
    String failure,
  ) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This institute has no phone number yet.'),
        ),
      );
      return;
    }
    final ok = await open(phone);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failure Number: $phone')),
      );
    }
  }
}

class _CourseCover extends StatelessWidget {
  const _CourseCover({required this.course, required this.category});

  final Course course;
  final EducationCategory category;

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (course.mode) {
      CourseMode.online => 'Online Live',
      CourseMode.offline => 'In-Person',
      CourseMode.hybrid => 'Hybrid',
    };
    return SizedBox(
      height: 168,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (course.coverImage.isEmpty)
            const ColoredBox(color: Color(0xFF0F172A))
          else
            AppNetworkImage(url: course.coverImage, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xCC070B14)],
              ),
            ),
          ),
          if (category != EducationCategory.all)
            Positioned(
              left: 10,
              top: 10,
              child: _badge(category.label, const Color(0xFF4C1D95)),
            ),
          Positioned(
            right: 10,
            top: 10,
            child: _badge(
              modeLabel,
              Colors.black.withValues(alpha: 0.35),
              outlined: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? const Color(0x660B0F19) : color,
        borderRadius: BorderRadius.circular(8),
        border: outlined ? Border.all(color: Colors.white70) : null,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
