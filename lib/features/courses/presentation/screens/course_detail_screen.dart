import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart'
    show formatInr, RatingBadge;
import '../widgets/external_link.dart';
import '../../domain/course.dart';
import '../course_providers.dart';
import '../widgets/course_demo_actions.dart';
import '../widgets/feedback_dialog.dart';

/// Course details with batches and enroll/drop actions.
///
/// Section order follows the reference design: hero image, name +
/// verified institute, location, plain-language description, faculty,
/// duration/timings/mode chips, fee & discount, demo, available
/// batches, reviews -- with a sticky bottom bar that always shows the
/// price and jumps straight to batch selection.
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({required this.courseId, super.key});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(moduleEnabledProvider('courses'));
    final courseAsync = ref.watch(courseDetailProvider(courseId));

    if (!enabled) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.courses)),
        body: EmptyState(
          icon: Icons.school_outlined,
          title: l10n.educationUnavailable,
          message: l10n.educationUnavailableMessage,
        ),
      );
    }

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
        ),
        data: (course) => _CourseBody(course: course),
      ),
    );
  }
}

class _CourseBody extends ConsumerStatefulWidget {
  const _CourseBody({required this.course});

  final Course course;

  @override
  ConsumerState<_CourseBody> createState() => _CourseBodyState();
}

class _CourseBodyState extends ConsumerState<_CourseBody> {
  final GlobalKey _batchesKey = GlobalKey();

  void _jumpToBatches() {
    final context = _batchesKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Future<void> _share(Course course) async {
    final l10n = AppLocalizations.of(context);
    final link = 'https://bookmyspace.app/course/${course.id}';
    await Clipboard.setData(ClipboardData(text: '${course.title} — $link'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.linkCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final demoEnabled = ref.watch(moduleEnabledProvider('demo_registration'));
    final feedback =
        ref.watch(courseFeedbackProvider(course.id)).valueOrNull ?? const [];
    final avgRating = feedback.isEmpty
        ? 0.0
        : feedback.map((f) => f.rating).reduce((a, b) => a + b) /
            feedback.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            actions: [
              IconButton(
                tooltip: l10n.share,
                icon: const Icon(Icons.share_rounded),
                onPressed: () => _share(course),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: AppNetworkImage(
                url: course.coverImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (course.instituteVerified)
                        const Icon(Icons.verified_rounded,
                            color: AppTheme.violet),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          course.instituteName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (feedback.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        RatingBadge(rating: avgRating, count: feedback.length),
                      ],
                    ],
                  ),
                  if (course.instituteCity.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 15,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          course.instituteCity,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (course.description.isNotEmpty) ...[
                    Text(l10n.details, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      course.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (course.syllabusPoints.isNotEmpty) ...[
                    Text(l10n.whatYouLearn, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ...course.syllabusPoints.map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: AppTheme.violet),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                point,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (course.instituteModules.enabled('faculty') &&
                      course.faculty.isNotEmpty) ...[
                    Text(l10n.faculty, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ...course.faculty.map(_FacultyTile.new),
                    const SizedBox(height: 20),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailChip(
                        icon: Icons.school_rounded,
                        label: _modeLabel(l10n, course.mode),
                      ),
                      _DetailChip(
                        icon: Icons.calendar_month_rounded,
                        label: l10n.durationWeeks.replaceAll(
                          '{weeks}',
                          '${course.durationWeeks}',
                        ),
                      ),
                      if (course.instructorName.isNotEmpty)
                        _DetailChip(
                          icon: Icons.person_rounded,
                          label: '${l10n.instructor}: ${course.instructorName}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FeeCard(course: course),
                  const SizedBox(height: 20),
                  if (course.hasDemo &&
                      demoEnabled &&
                      course.instituteModules.enabled('demo')) ...[
                    Text(l10n.demoAndRegistration,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    CourseDemoActions(course: course),
                    const SizedBox(height: 20),
                  ],
                  if (course.brochureUrl.isNotEmpty &&
                      course.instituteModules.enabled('brochure')) ...[
                    OutlinedButton.icon(
                      onPressed: () => openMediaUrl(course.brochureUrl),
                      icon: const Icon(Icons.description_outlined),
                      label: Text(l10n.downloadBrochure),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  KeyedSubtree(
                    key: _batchesKey,
                    child: Text(
                      l10n.enrollInCourse,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (course.batches.isEmpty)
                    Text(
                      l10n.noCourses,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...course.batches.map(
                      (b) => _BatchTile(courseId: course.id, batch: b),
                    ),
                  const SizedBox(height: 20),
                  if (course.faqs.isNotEmpty) ...[
                    Text(l10n.faq, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    ...course.faqs.map(_FaqTile.new),
                    const SizedBox(height: 20),
                  ],
                  _CourseFeedbackSection(courseId: course.id),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _StickyEnrollBar(
        course: course,
        onEnroll: _jumpToBatches,
      ),
    );
  }

  static String _modeLabel(AppLocalizations l10n, CourseMode mode) =>
      switch (mode) {
        CourseMode.online => l10n.modeOnline,
        CourseMode.offline => l10n.modeOffline,
        CourseMode.hybrid => l10n.modeHybrid,
      };
}

class _StickyEnrollBar extends StatelessWidget {
  const _StickyEnrollBar({required this.course, required this.onEnroll});

  final Course course;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    course.payableAmount <= 0
                        ? l10n.freeEvent
                        : formatInr(course.payableAmount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.violet,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    l10n.durationWeeks
                        .replaceAll('{weeks}', '${course.durationWeeks}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key("course-sticky-enroll-cta"),
              onPressed: onEnroll,
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 48),
              ),
              child: Text(l10n.enrollNow),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppTheme.violet),
      label: Text(label),
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hasDiscount = course.discountAmount > 0;
    return GlassmorphicCard(
      borderRadius: 16,
      isInteractive: false,
      enableEntrance: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.feeBreakdown,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _FeeRow(
            label: l10n.courseFee,
            value: course.isFree ? l10n.freeEvent : formatInr(course.feeAmount),
          ),
          if (hasDiscount)
            _FeeRow(
              label: l10n.discount,
              value: '- ${formatInr(course.discountAmount)}',
            ),
          if (hasDiscount || !course.isFree) ...[
            const Divider(height: 18),
            _FeeRow(
              label: l10n.totalPayable,
              value: course.payableAmount <= 0
                  ? l10n.freeEvent
                  : formatInr(course.payableAmount),
              bold: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bold ? null : theme.colorScheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: (bold
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyMedium)
                ?.copyWith(
              color: bold ? AppTheme.violet : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacultyTile extends StatelessWidget {
  const _FacultyTile(this.faculty);

  final CourseFaculty faculty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: faculty.photoUrl.isNotEmpty
                  ? AppNetworkImage(url: faculty.photoUrl, fit: BoxFit.cover)
                  : ColoredBox(
                      color: AppTheme.violet.withValues(alpha: 0.12),
                      child: const Icon(Icons.person_rounded,
                          color: AppTheme.violet),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faculty.name,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (faculty.role.isNotEmpty)
                  Text(
                    faculty.role,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.violet,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (faculty.qualification.isNotEmpty)
                  Text(faculty.qualification, style: theme.textTheme.bodySmall),
                if (faculty.specialization.isNotEmpty)
                  Text(faculty.specialization,
                      style: theme.textTheme.bodySmall),
                if (faculty.experienceText.isNotEmpty)
                  Text(faculty.experienceText,
                      style: theme.textTheme.bodySmall),
                if (faculty.bio.isNotEmpty)
                  Text(
                    faculty.bio,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _FaqTile extends StatefulWidget {
  const _FaqTile(this.faq);

  final CourseFaq faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassmorphicCard(
        borderRadius: 14,
        isInteractive: false,
        enableEntrance: false,
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              widget.faq.question,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            onExpansionChanged: (v) => setState(() => _expanded = v),
            trailing: Icon(
              _expanded ? Icons.remove_rounded : Icons.add_rounded,
              color: AppTheme.violet,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.faq.answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseFeedbackSection extends ConsumerWidget {
  const _CourseFeedbackSection({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (!ref.watch(moduleEnabledProvider('course_feedback'))) {
      return const SizedBox.shrink();
    }
    final feedbackAsync = ref.watch(courseFeedbackProvider(courseId));
    final isEnrolled = ref.watch(isEnrolledInCourseProvider(courseId));
    final signedIn = ref.watch(currentUserProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.feedback, style: theme.textTheme.titleMedium),
            ),
            if (isEnrolled)
              TextButton.icon(
                onPressed: () =>
                    showFeedbackDialog(context, courseId: courseId),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: Text(l10n.writeFeedback),
              )
            else if (!signedIn)
              TextButton.icon(
                onPressed: () => context.push(
                  loginLocationFor(
                    Uri.parse(
                      AppRoutes.courseDetails.replaceAll(':id', courseId),
                    ),
                  ),
                ),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: Text(l10n.signInToEnroll),
              ),
          ],
        ),
        const SizedBox(height: 6),
        feedbackAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(courseFeedbackProvider(courseId)),
          ),
          data: (items) => items.isEmpty
              ? Text(
                  l10n.noFeedback,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: [
                    for (final fb in items) _FeedbackTile(feedback: fb),
                  ],
                ),
        ),
      ],
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.feedback});

  final CourseFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        borderRadius: 14,
        isInteractive: false,
        enableEntrance: false,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded,
                    size: 18, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  '${feedback.rating}.0',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (feedback.authorName.isNotEmpty)
                  Text(
                    feedback.authorName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (feedback.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(feedback.comment, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _BatchTile extends ConsumerStatefulWidget {
  const _BatchTile({required this.courseId, required this.batch});

  final String courseId;
  final CourseBatch batch;

  @override
  ConsumerState<_BatchTile> createState() => _BatchTileState();
}

class _BatchTileState extends ConsumerState<_BatchTile> {
  bool _busy = false;
  String? _error;

  CourseBatch get batch => widget.batch;

  Future<void> _enroll() async {
    if (ref.read(currentUserProvider) == null) {
      context.push(
        loginLocationFor(
          Uri.parse(AppRoutes.courseDetails.replaceAll(':id', widget.courseId)),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(courseEnrollmentControllerProvider).enroll(
            courseId: widget.courseId,
            batchId: batch.id,
          );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDrop() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dropEnrollment),
        content: Text(l10n.dropEnrollmentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(courseEnrollmentControllerProvider).drop(
            courseId: widget.courseId,
            batchId: batch.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.enrollmentDropped)),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        borderRadius: 16,
        isInteractive: false,
        enableEntrance: false,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              batch.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (batch.userEnrolled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.violet.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                l10n.enrolled,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.violet,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.batchStartsOn} ${DateFormat.yMMMd().format(batch.startsOn)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        batch.seatsLeft > 0
                            ? l10n.seatsLeft.replaceAll(
                                '{count}',
                                '${batch.seatsLeft}',
                              )
                            : l10n.soldOut,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: batch.seatsLeft > 0
                              ? AppTheme.violet
                              : AppTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                batch.userEnrolled
                    ? OutlinedButton(
                        onPressed: _busy ? null : _confirmDrop,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(_busy ? l10n.loading : l10n.dropEnrollment),
                      )
                    : FilledButton(
                        key: Key("batch-enroll-${batch.id}"),
                        onPressed: _busy || batch.isFull ? null : _enroll,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          ref.watch(currentUserProvider) == null
                              ? l10n.signInToEnroll
                              : l10n.enrollNow,
                        ),
                      ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
