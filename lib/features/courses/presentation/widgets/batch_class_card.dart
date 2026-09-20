import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';
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
    final seats = '${batch.seatsLeft} seats left out of ${batch.capacity}';
    final progress = batch.capacity == 0
        ? 0.0
        : (batch.enrolledCount / batch.capacity).clamp(0.0, 1.0);
    final fee = batch.feeAmount > 0 ? batch.feeAmount : course.feeAmount;

    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  course.instituteName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (course.instituteVerified)
                const Icon(Icons.verified_rounded,
                    size: 16, color: Colors.green),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            course.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (batch.subject.isNotEmpty || course.instructorName.isNotEmpty)
            Text(
              [
                if (batch.subject.isNotEmpty) batch.subject,
                if (course.instructorName.isNotEmpty) course.instructorName,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pill(mode.name.toUpperCase(), AppTheme.violet),
              if (batch.timing.isNotEmpty) _pill(batch.timing, AppTheme.cyan),
              if (batch.label.isNotEmpty) _pill(batch.label, AppTheme.brand),
              if (course.hasDemo) _pill('Free Demo Trial', AppTheme.success),
            ],
          ),
          const SizedBox(height: 10),
          Text(seats, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatInr(fee),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.violet,
                  ),
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
                  child: const Text('Book Free Trial'),
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
                child: Text(batch.isFull ? 'Waitlist' : 'Enroll Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
