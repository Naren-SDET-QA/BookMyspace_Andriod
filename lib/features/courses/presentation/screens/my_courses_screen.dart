import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../domain/course.dart';
import '../course_providers.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/invoice_view.dart';

/// The signed-in learner's active enrollments with batch, invoice and feedback
/// actions. Prompts sign-in (preserving this destination) when logged out.
class MyCoursesScreen extends ConsumerWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(moduleEnabledProvider('courses'));
    final user = ref.watch(currentUserProvider);

    if (!enabled) {
      return _Scaffold(
        l10n: l10n,
        body: EmptyState(
          icon: Icons.school_outlined,
          title: l10n.educationUnavailable,
          message: l10n.educationUnavailableMessage,
        ),
      );
    }

    if (user == null) {
      return _Scaffold(
        l10n: l10n,
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: l10n.signInToEnroll,
          message: l10n.noMyCoursesMessage,
          action: FilledButton(
            onPressed: () => context.push(
              loginLocationFor(Uri.parse(AppRoutes.myCourses)),
            ),
            child: Text(l10n.signInToEnroll),
          ),
        ),
      );
    }

    final mine = ref.watch(myCoursesProvider);
    return _Scaffold(
      l10n: l10n,
      body: mine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myCoursesProvider),
        ),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.backpack_outlined,
                title: l10n.noMyCourses,
                message: l10n.noMyCoursesMessage,
                action: FilledButton(
                  onPressed: () => context.go(AppRoutes.coursesList),
                  child: Text(l10n.courses),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _EnrollmentCard(
                  enrollment: items[i],
                  studentName:
                      user.fullName.isNotEmpty ? user.fullName : user.phone,
                ),
              ),
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.l10n, required this.body});

  final AppLocalizations l10n;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myCourses)),
      body: body,
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.enrollment, required this.studentName});

  final MyEnrolledCourse enrollment;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final course = enrollment.course;
    final batch = enrollment.batch;

    return GlassmorphicCard(
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
                child: Text(
                  course.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          if (course.instituteName.isNotEmpty)
            Text(
              course.instituteName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            '${l10n.preferredBatch}: ${batch.label}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showInvoiceDialog(
                    context,
                    invoice: composeInvoice(
                      enrollment,
                      studentName: studentName,
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: Text(l10n.viewInvoice),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      showFeedbackDialog(context, courseId: course.id),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: Text(l10n.feedback),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppTheme.violet),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
