import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../domain/course.dart';
import '../course_providers.dart';

/// Owner course management: lists every course (draft + published) the owner's
/// institute(s) hold, with a status chip and edit action. Creating/editing opens
/// [OwnerCourseEditorScreen]. Owners only see their own institutes via RLS.
class OwnerCoursesScreen extends ConsumerWidget {
  const OwnerCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(moduleEnabledProvider('courses'));
    final coursesAsync = ref.watch(ownerCoursesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My courses'),
        actions: [
          if (enabled)
            IconButton(
              tooltip: 'New course',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => context.push(AppRoutes.ownerCourseCreate),
            ),
        ],
      ),
      floatingActionButton: enabled
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.ownerCourseCreate),
              backgroundColor: AppTheme.violet,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New course'),
            )
          : null,
      body: !enabled
          ? const EmptyState(
              icon: Icons.school_outlined,
              title: 'Education is unavailable',
              message:
                  'This module is currently disabled by the administrator.',
            )
          : coursesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(ownerCoursesProvider),
              ),
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: Icons.school_outlined,
                      title: 'No courses yet',
                      message: 'Create your first course to get started.',
                      action: FilledButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.ownerCourseCreate),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('New course'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.violet,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _OwnerCourseTile(course: items[i]),
                    ),
            ),
    );
  }
}

class _OwnerCourseTile extends StatelessWidget {
  const _OwnerCourseTile({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final published = course.isPublished;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push(AppRoutes.ownerCourseEdit, extra: course),
        title: Text(course.title),
        subtitle: Text(
          '${course.durationWeeks} weeks • '
          '${course.batches.length} batch(es)',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (published ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                published ? 'Published' : 'Draft',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: published ? Colors.green : Colors.orange.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
