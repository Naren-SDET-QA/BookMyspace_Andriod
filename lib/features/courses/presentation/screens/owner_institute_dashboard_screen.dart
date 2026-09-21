import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../cms/domain/configurable_form.dart';
import '../../../cms/domain/target_modules.dart';
import '../../../cms/presentation/widgets/configurable_form_builder.dart';
import '../../../cms/presentation/widgets/configurable_form_fields.dart';
import '../../../modules/presentation/module_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';
import '../../domain/education_category.dart';
import '../course_providers.dart';

class OwnerInstituteDashboardScreen extends ConsumerWidget {
  const OwnerInstituteDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(moduleEnabledProvider('courses'));
    if (!enabled) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.school_outlined,
          title: 'Education is unavailable',
          message: 'This module is currently disabled by the administrator.',
        ),
      );
    }

    final coursesAsync = ref.watch(ownerCoursesProvider);
    final institutesAsync = ref.watch(ownerInstitutesProvider);
    final admissionsAsync = ref.watch(ownerAdmissionsProvider);

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Institute Dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Batches'),
              Tab(text: 'Admissions'),
              Tab(text: 'Faculty'),
              Tab(text: 'Registration Form'),
              Tab(text: 'Branches'),
              Tab(text: 'Settings'),
              Tab(text: 'Profile'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'New course',
              onPressed: () => context.push(AppRoutes.ownerCourseCreate),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: coursesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () {
              ref.invalidate(ownerCoursesProvider);
              ref.invalidate(ownerInstitutesProvider);
              ref.invalidate(ownerAdmissionsProvider);
            },
          ),
          data: (courses) {
            final institutes = institutesAsync.valueOrNull ?? const [];
            final admissions = admissionsAsync.valueOrNull ?? const [];
            final batches = [
              for (final course in courses) ...course.batches,
            ];
            final activeBatches =
                batches.where((batch) => batch.isActive).length;
            final enrolled =
                batches.fold<int>(0, (sum, batch) => sum + batch.enrolledCount);
            final pending =
                admissions.where((item) => item.status == 'pending').length;
            final revenue = batches.fold<double>(
              0,
              (sum, batch) =>
                  sum +
                  (batch.feeAmount > 0 ? batch.feeAmount : 0) *
                      batch.enrolledCount,
            );

            return Column(
              children: [
                // ── Overview Metrics ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Active Batches',
                          value: '$activeBatches',
                          icon: Icons.event_note_rounded,
                          color: AppTheme.violet,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          label: 'Enrolled Students',
                          value: '$enrolled',
                          icon: Icons.groups_rounded,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Pending Trials',
                          value: '$pending',
                          icon: Icons.pending_actions_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          label: 'Monthly Revenue',
                          value: formatInr(revenue),
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Tab Content ──
                Expanded(
                  child: TabBarView(
                    children: [
                      _BatchesTab(courses: courses),
                      _AdmissionsTab(admissions: admissions),
                      _FacultyTab(
                        courses: courses,
                        institutes: institutes,
                      ),
                      _RegistrationFormTab(institutes: institutes),
                      _BranchesTab(institutes: institutes),
                      _ModulesTab(institutes: institutes),
                      _ProfileTab(institutes: institutes),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
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

class _BatchesTab extends ConsumerWidget {
  const _BatchesTab({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = [
      for (final course in courses)
        for (final batch in course.batches) (course: course, batch: batch),
    ];

    // Group by status
    final active = rows
        .where((r) =>
            r.batch.isActive && !r.batch.startsOn.isAfter(DateTime.now()))
        .toList();
    final upcoming = rows
        .where(
            (r) => r.batch.isActive && r.batch.startsOn.isAfter(DateTime.now()))
        .toList();
    final completed = rows.where((r) => !r.batch.isActive).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: courses.isEmpty
              ? null
              : () => _openBatchEditor(context, ref, courses.first, null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add New Batch'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No batches yet',
            message: 'Create a course, then add classroom batches.',
          )
        else ...[
          if (active.isNotEmpty) ...[
            _sectionHeader(
                'Active Batches', active.length, const Color(0xFF10B981)),
            const SizedBox(height: 8),
            ...active.map((row) => _batchTile(context, ref, row)),
            const SizedBox(height: 16),
          ],
          if (upcoming.isNotEmpty) ...[
            _sectionHeader(
                'Upcoming Batches', upcoming.length, AppTheme.violet),
            const SizedBox(height: 8),
            ...upcoming.map((row) => _batchTile(context, ref, row)),
            const SizedBox(height: 16),
          ],
          if (completed.isNotEmpty) ...[
            _sectionHeader('Completed', completed.length,
                theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            ...completed.map((row) => _batchTile(context, ref, row)),
          ],
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _batchTile(
    BuildContext context,
    WidgetRef ref,
    ({Course course, CourseBatch batch}) row,
  ) {
    final batch = row.batch;
    final status = !batch.isActive
        ? 'Completed'
        : batch.startsOn.isAfter(DateTime.now())
            ? 'Upcoming'
            : 'Active';
    final statusColor = status == 'Active'
        ? const Color(0xFF10B981)
        : status == 'Upcoming'
            ? AppTheme.violet
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    batch.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: batch.admissionsOpen && batch.isActive,
                  onChanged: batch.isActive
                      ? (value) {
                          ref.read(ownerCourseControllerProvider).saveBatch(
                                batchId: batch.id,
                                courseId: row.course.id,
                                label: batch.label,
                                startsOn: batch.startsOn,
                                capacity: batch.capacity,
                                isActive: batch.isActive,
                                admissionsOpen: value,
                                timing: batch.timing,
                                feeAmount: batch.feeAmount,
                                mode: batch.mode,
                                subject: batch.subject,
                                categorySlug: batch.categorySlug,
                              );
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${row.course.title} · ${batch.timing.isNotEmpty ? batch.timing : 'No timing set'}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat(
                    Icons.people_rounded,
                    '${batch.enrolledCount}/${batch.capacity}',
                    AppTheme.violet),
                const SizedBox(width: 12),
                _miniStat(
                    Icons.payments_rounded,
                    formatInr(batch.feeAmount > 0
                        ? batch.feeAmount
                        : row.course.feeAmount),
                    const Color(0xFF10B981)),
                const Spacer(),
                if (batch.isActive)
                  IconButton(
                    tooltip: 'Edit batch',
                    onPressed: () =>
                        _openBatchEditor(context, ref, row.course, batch),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _AdmissionsTab extends ConsumerWidget {
  const _AdmissionsTab({required this.admissions});

  final List<CourseDemoRegistration> admissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pending = admissions.where((a) => a.status == 'pending').toList();
    final processed = admissions.where((a) => a.status != 'pending').toList();

    if (admissions.isEmpty) {
      return const EmptyState(
        icon: Icons.how_to_reg_outlined,
        title: 'No admission requests',
        message: 'Trial bookings and enrollments will appear here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          Text(
            'Pending Approval (${pending.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(height: 8),
          ...pending.map((item) => _admissionCard(context, ref, item, theme)),
          const SizedBox(height: 16),
        ],
        if (processed.isNotEmpty) ...[
          Text(
            'Processed (${processed.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...processed.map((item) => _admissionCard(context, ref, item, theme)),
        ],
      ],
    );
  }

  Widget _admissionCard(
    BuildContext context,
    WidgetRef ref,
    CourseDemoRegistration item,
    ThemeData theme,
  ) {
    final isPending = item.status == 'pending';
    final statusColor = isPending
        ? const Color(0xFFF59E0B)
        : item.status == 'contacted'
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Text(
                    item.studentName.isNotEmpty
                        ? item.studentName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.studentName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${item.mobile} · ${item.preferredBatch.isNotEmpty ? item.preferredBatch : 'Any batch'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(courseRepositoryProvider)
                          .setAdmissionStatus(
                            registrationId: item.id,
                            status: 'cancelled',
                          )
                          .then((_) => ref.invalidate(ownerAdmissionsProvider)),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => ref
                          .read(courseRepositoryProvider)
                          .setAdmissionStatus(
                            registrationId: item.id,
                            status: 'contacted',
                          )
                          .then((_) => ref.invalidate(ownerAdmissionsProvider)),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FacultyTab extends ConsumerWidget {
  const _FacultyTab({required this.courses, required this.institutes});

  final List<Course> courses;
  final List<Institute> institutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faculty = [
      for (final course in courses) ...course.faculty,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: courses.isEmpty && institutes.isEmpty
              ? null
              : () => _addFaculty(
                    context,
                    ref,
                    courses.isNotEmpty ? courses.first : null,
                    institutes.isEmpty ? null : institutes.first,
                  ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Instructor'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
        ),
        const SizedBox(height: 12),
        if (faculty.isEmpty)
          const EmptyState(
            icon: Icons.badge_outlined,
            title: 'No faculty yet',
            message: 'Add instructor profiles for your batches.',
          )
        else
          ...faculty.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.violet.withValues(alpha: 0.12),
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.violet,
                    ),
                  ),
                ),
                title: Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [
                    if (item.designation.isNotEmpty) item.designation,
                    if (item.role.isNotEmpty) item.role,
                    if (item.qualification.isNotEmpty) item.qualification,
                    if (item.experienceText.isNotEmpty) item.experienceText,
                    if (item.bio.isNotEmpty) item.bio,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.institutes});

  final List<Institute> institutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (institutes.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No institute profile',
        message: 'Create an institute under your organization first.',
      );
    }
    final institute = institutes.first;
    const amenityOptions = [
      'AC',
      'Projector',
      'Lab',
      'Turf',
      'WiFi',
    ];
    final selected = {...institute.amenities};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Institute Header ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.violet.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.violet.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: AppTheme.violet),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          institute.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (institute.isVerified)
                          const Text(
                            'Verified Institute',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Registration Info ──
        _infoSection('Registration Info', [
          _infoRow('Address',
              institute.address.isEmpty ? 'Not set' : institute.address),
          _infoRow('City', institute.city.isEmpty ? 'Not set' : institute.city),
          _infoRow(
              'Phone', institute.phone.isEmpty ? 'Not set' : institute.phone),
          _infoRow(
              'Email', institute.email.isEmpty ? 'Not set' : institute.email),
          _infoRow('Website',
              institute.website.isEmpty ? 'Not set' : institute.website),
        ]),
        const SizedBox(height: 16),
        // ── Classroom Amenities ──
        Text(
          'Classroom Amenities',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amenity in amenityOptions)
              FilterChip(
                label: Text(amenity),
                selected: selected.contains(amenity),
                onSelected: (on) {
                  final next = {...selected};
                  if (on) {
                    next.add(amenity);
                  } else {
                    next.remove(amenity);
                  }
                  ref
                      .read(courseRepositoryProvider)
                      .updateInstitute(
                        instituteId: institute.id,
                        amenities: next.toList(),
                      )
                      .then((_) => ref.invalidate(ownerInstitutesProvider));
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _addFaculty(
  BuildContext context,
  WidgetRef ref,
  Course? course,
  Institute? institute,
) async {
  final name = TextEditingController();
  final role = TextEditingController();
  final bio = TextEditingController();
  final qualification = TextEditingController();
  final experience = TextEditingController();
  final demoUrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Instructor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: role,
              decoration: const InputDecoration(labelText: 'Designation'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qualification,
              decoration: const InputDecoration(labelText: 'Qualification'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: experience,
              decoration: const InputDecoration(labelText: 'Experience'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: demoUrl,
              decoration: const InputDecoration(labelText: 'Demo video URL'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bio,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved != true || name.text.trim().isEmpty) return;
  await ref.read(ownerCourseControllerProvider).addFaculty(
        courseId: course?.id ?? '',
        instituteId: institute?.id ?? course?.instituteId ?? '',
        name: name.text.trim(),
        role: role.text.trim(),
        bio: bio.text.trim(),
        qualification: qualification.text.trim(),
        experienceText: experience.text.trim(),
        demoUrl: demoUrl.text.trim(),
      );
}

class _RegistrationFormTab extends ConsumerStatefulWidget {
  const _RegistrationFormTab({required this.institutes});

  final List<Institute> institutes;

  @override
  ConsumerState<_RegistrationFormTab> createState() =>
      _RegistrationFormTabState();
}

class _RegistrationFormTabState extends ConsumerState<_RegistrationFormTab> {
  ConfigurableFormSchema? _schema;
  bool _busy = false;

  Institute? get _institute =>
      widget.institutes.isEmpty ? null : widget.institutes.first;

  @override
  Widget build(BuildContext context) {
    final institute = _institute;
    if (institute == null) {
      return const EmptyState(
        icon: Icons.rule_rounded,
        title: 'No institute',
        message: 'Create an institute before configuring registration.',
      );
    }
    final aadhaarAllowed = institute.modules.enabled('aadhaar');
    final schema = _schema ??
        (institute.registrationForm.editorFields.isEmpty
            ? ConfigurableFormSchema.defaults()
            : institute.registrationForm);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Students only see fields you enable. Aadhaar stays off unless you turn it on in Settings.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ConfigurableFormBuilder(
          schema: schema,
          aadhaarAllowed: aadhaarAllowed,
          busy: _busy,
          onChanged: (next) => setState(() => _schema = next),
          onPreview: () => _preview(schema),
          onPublish: () => _publish(institute, schema),
        ),
      ],
    );
  }

  Future<void> _preview(ConfigurableFormSchema schema) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ConfigurableFormFields(
            schema: schema.publish(),
            values: const {},
            onChanged: (_, __) {},
          ),
        );
      },
    );
  }

  Future<void> _publish(
    Institute institute,
    ConfigurableFormSchema schema,
  ) async {
    final published = schema.publish();
    final errors = published.setupErrors();
    if (errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(ownerCourseControllerProvider).saveInstituteConfig(
            instituteId: institute.id,
            registrationForm: published,
          );
      if (mounted) setState(() => _schema = published);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _BranchesTab extends ConsumerWidget {
  const _BranchesTab({required this.institutes});

  final List<Institute> institutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (institutes.isEmpty) {
      return const EmptyState(
        icon: Icons.location_on_outlined,
        title: 'No institute',
        message: 'Create an institute before adding branches.',
      );
    }
    final institute = institutes.first;
    if (!institute.modules.enabled('location')) {
      return const EmptyState(
        icon: Icons.location_off_outlined,
        title: 'Location is turned off',
        message: 'Enable Address in Settings to manage branches.',
      );
    }
    final branchesAsync = ref.watch(instituteBranchesProvider(institute.id));
    return branchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(instituteBranchesProvider(institute.id)),
      ),
      data: (branches) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () => _editBranch(context, ref, institute, null),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Add branch'),
            ),
            const SizedBox(height: 12),
            if (branches.isEmpty)
              const EmptyState(
                icon: Icons.store_mall_directory_outlined,
                title: 'No branches yet',
                message: 'Add a main campus or an online-only branch.',
              )
            else
              ...branches.map(
                (branch) => Card(
                  child: ListTile(
                    title: Text(branch.name),
                    subtitle: Text(
                      [
                        if (branch.isOnlineOnly) 'Online only',
                        if (branch.city.isNotEmpty) branch.city,
                        if (branch.address.isNotEmpty) branch.address,
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () =>
                          ref.read(ownerCourseControllerProvider).deleteBranch(
                                instituteId: institute.id,
                                branchId: branch.id,
                              ),
                    ),
                    onTap: () => _editBranch(context, ref, institute, branch),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> _editBranch(
  BuildContext context,
  WidgetRef ref,
  Institute institute,
  InstituteBranch? existing,
) async {
  final name = TextEditingController(text: existing?.name ?? 'Main branch');
  final address = TextEditingController(text: existing?.address ?? '');
  final city = TextEditingController(text: existing?.city ?? '');
  var online = existing?.isOnlineOnly ?? false;
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: Text(existing == null ? 'Add branch' : 'Edit branch'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Branch name'),
                ),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Online only'),
                  value: online,
                  onChanged: (v) => setLocal(() => online = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  if (saved != true) return;
  await ref.read(ownerCourseControllerProvider).saveBranch(
        InstituteBranch(
          id: existing?.id ?? '',
          instituteId: institute.id,
          name: name.text.trim(),
          address: address.text.trim(),
          city: city.text.trim(),
          isOnlineOnly: online,
          isPrimary: existing?.isPrimary ?? false,
          isActive: true,
        ),
      );
}

class _ModulesTab extends ConsumerWidget {
  const _ModulesTab({required this.institutes});

  final List<Institute> institutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (institutes.isEmpty) {
      return const EmptyState(
        icon: Icons.tune_rounded,
        title: 'No institute',
        message: 'Create an institute first.',
      );
    }
    final institute = institutes.first;
    final platformCourses = ref.watch(moduleEnabledProvider('courses'));
    final platformDemo = ref.watch(moduleEnabledProvider('demo_registration'));
    final platformReviews = ref.watch(moduleEnabledProvider('course_feedback'));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Turn features on only when you will actually use them. Students never see a disabled module.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final entry in TargetModuleConfig.catalog.entries)
          SwitchListTile(
            title: Text(entry.value),
            value: institute.modules.enabled(entry.key),
            onChanged: !_platformAllows(
                    entry.key, platformCourses, platformDemo, platformReviews)
                ? null
                : (value) {
                    ref.read(ownerCourseControllerProvider).saveInstituteConfig(
                          instituteId: institute.id,
                          modules:
                              institute.modules.copyWithFlag(entry.key, value),
                        );
                  },
          ),
      ],
    );
  }

  bool _platformAllows(
    String key,
    bool courses,
    bool demo,
    bool reviews,
  ) {
    if (!courses) return false;
    if ((key == 'demo' || key == 'brochure' || key == 'registration') &&
        !demo) {
      return false;
    }
    if (key == 'reviews' && !reviews) return false;
    return true;
  }
}

Future<void> _openBatchEditor(
  BuildContext context,
  WidgetRef ref,
  Course course,
  CourseBatch? existing,
) async {
  final title = TextEditingController(text: existing?.label ?? '');
  final subject = TextEditingController(text: existing?.subject ?? '');
  final timing = TextEditingController(text: existing?.timing ?? '');
  final fee = TextEditingController(
    text: existing == null ? '' : '${existing.feeAmount.round()}',
  );
  final capacity = TextEditingController(
    text: existing == null ? '30' : '${existing.capacity}',
  );
  var mode = existing?.mode ?? course.mode;
  var category = EducationCategory.fromSlug(existing?.categorySlug);
  var startsOn =
      existing?.startsOn ?? DateTime.now().add(const Duration(days: 7));

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(existing == null ? 'Add Batch' : 'Edit Batch'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration:
                          const InputDecoration(labelText: 'Batch title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: subject,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<EducationCategory>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: EducationCategory.values
                          .where((c) => c != EducationCategory.all)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => category = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: timing,
                      decoration: const InputDecoration(
                        labelText: 'Timings',
                        hintText: '06:00 AM - 08:00 AM',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CourseMode>(
                      initialValue: mode,
                      decoration:
                          const InputDecoration(labelText: 'Delivery mode'),
                      items: CourseMode.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => mode = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: fee,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Course fee (INR)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum seat capacity',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start date'),
                      subtitle: Text(DateFormat.yMMMd().format(startsOn)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startsOn,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) setState(() => startsOn = picked);
                      },
                    ),
                    Text(
                      'Primary faculty: ${course.instructorName.isEmpty ? 'Set on the course' : course.instructorName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  if (saved != true || title.text.trim().isEmpty) return;
  await ref.read(ownerCourseControllerProvider).saveBatch(
        batchId: existing?.id,
        courseId: course.id,
        label: title.text.trim(),
        startsOn: startsOn,
        capacity: int.tryParse(capacity.text.trim()) ?? 30,
        timing: timing.text.trim(),
        feeAmount: double.tryParse(fee.text.trim()) ?? 0,
        mode: mode,
        subject: subject.text.trim(),
        categorySlug: category == EducationCategory.all ? '' : category.slug,
      );
}
