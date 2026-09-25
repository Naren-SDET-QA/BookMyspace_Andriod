import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';
import '../../domain/education_category.dart';
import 'class_enrollment_sheet.dart';

class BatchClassCard extends StatelessWidget {
  const BatchClassCard({
    super.key,
    required this.course,
    required this.batch,
  });

  final Course course;
  final CourseBatch batch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = batch.mode ?? course.mode;
    final seatsLeft = batch.seatsLeft;
    final total = batch.capacity;
    final progress =
        total == 0 ? 0.0 : (batch.enrolledCount / total).clamp(0.0, 1.0);
    final fee = batch.feeAmount > 0 ? batch.feeAmount : course.feeAmount;
    final isDark = theme.brightness == Brightness.dark;
    final category = EducationCategory.fromSlug(
        batch.categorySlug.isNotEmpty ? batch.categorySlug : course.categoryId);

    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: Institute + verified badge ──
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_rounded,
                    size: 18, color: AppTheme.violet),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            course.instituteName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (course.instituteVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 14, color: Color(0xFF10B981)),
                        ],
                      ],
                    ),
                    if (course.instituteCity.isNotEmpty)
                      Text(
                        course.instituteCity,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Row 2: Course title ──
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          // ── Row 3: Instructor credentials ──
          if (course.instructorName.isNotEmpty || batch.subject.isNotEmpty)
            Row(
              children: [
                if (course.instructorName.isNotEmpty) ...[
                  Icon(Icons.person_rounded,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      course.instructorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (course.instructorName.isNotEmpty &&
                    batch.subject.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (batch.subject.isNotEmpty)
                  Flexible(
                    child: Text(
                      batch.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          // ── Row 4: Pills ──
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _pill(
                mode.name.toUpperCase(),
                AppTheme.violet,
                icon: mode == CourseMode.online
                    ? Icons.wifi_rounded
                    : mode == CourseMode.hybrid
                        ? Icons.wifi_tethering_rounded
                        : Icons.location_on_outlined,
              ),
              if (batch.timing.isNotEmpty)
                _pill(batch.timing, AppTheme.cyan,
                    icon: Icons.schedule_rounded),
              if (category != EducationCategory.all)
                _pill(category.label, AppTheme.brand,
                    icon: Icons.category_rounded),
              if (batch.label.isNotEmpty)
                _pill(batch.label, AppTheme.spotlightAmber),
              if (course.hasDemo)
                _pill('Free Demo Trial', AppTheme.success,
                    icon: Icons.play_circle_outline_rounded),
            ],
          ),
          const SizedBox(height: 10),
          // ── Row 5: Seat availability bar ──
          Row(
            children: [
              Icon(
                seatsLeft <= 3
                    ? Icons.event_seat_rounded
                    : Icons.event_available_rounded,
                size: 16,
                color: seatsLeft <= 3
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$seatsLeft seats left out of $total',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: seatsLeft <= 3 ? const Color(0xFFEF4444) : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          seatsLeft <= 3
                              ? const Color(0xFFEF4444)
                              : seatsLeft <= 10
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Row 6: Price + action buttons ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatInr(fee),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.violet,
                      ),
                    ),
                    if (fee > 0)
                      Text(
                        'per course',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (course.hasDemo)
                OutlinedButton(
                  onPressed: () => showClassEnrollmentSheet(
                    context,
                    course: course,
                    batch: batch,
                    isTrial: true,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 36),
                  ),
                  child:
                      const Text('Free Trial', style: TextStyle(fontSize: 12)),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: batch.isFull && !batch.waitlistEnabled
                    ? null
                    : () => showClassEnrollmentSheet(
                          context,
                          course: course,
                          batch: batch,
                          isTrial: false,
                        ),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(0, 36),
                  backgroundColor: AppTheme.violet,
                ),
                child: Text(
                  batch.isFull ? 'Waitlist' : 'Enroll Now',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
