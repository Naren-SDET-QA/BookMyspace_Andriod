import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/error_view.dart';
import '../course_providers.dart';
import '../widgets/course_card.dart';
import 'education_hub_screen.dart';

/// Admin education management. Module-level enable/disable/reorder is handled
/// by the existing feature-flag system ([AdminModulesScreen]); this screen
/// surfaces the education catalog (institutes + courses) and links to module
/// controls so admins never manage education through a second, parallel CMS.
class AdminEducationScreen extends ConsumerWidget {
  const AdminEducationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Education'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Institutes'),
              Tab(text: 'Courses'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.adminModules),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Modules'),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _AdminInstitutesTab(),
            _AdminCoursesTab(),
          ],
        ),
      ),
    );
  }
}

class _AdminInstitutesTab extends ConsumerWidget {
  const _AdminInstitutesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutesAsync = ref.watch(institutesProvider);
    return institutesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(institutesProvider),
      ),
      data: (items) => items.isEmpty
          ? const Center(child: Text('No institutes yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => InstituteCard(institute: items[i]),
            ),
    );
  }
}

class _AdminCoursesTab extends ConsumerWidget {
  const _AdminCoursesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(publishedCoursesProvider);
    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(publishedCoursesProvider),
      ),
      data: (items) => items.isEmpty
          ? const Center(child: Text('No published courses yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => CourseCard(course: items[i]),
            ),
    );
  }
}
