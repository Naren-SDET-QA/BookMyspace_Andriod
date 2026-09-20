import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Institute dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Batches'),
              Tab(text: 'Admissions'),
              Tab(text: 'Faculty'),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metric('Active batches', '$activeBatches'),
                      _metric('Enrolled students', '$enrolled'),
                      _metric('Pending trials', '$pending'),
                      _metric('Monthly fee revenue', formatInr(revenue)),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _BatchesTab(courses: courses),
                      _AdmissionsTab(admissions: admissions),
                      _FacultyTab(courses: courses),
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

  Widget _metric(String label, String value) {
    return SizedBox(
      width: 160,
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchesTab extends ConsumerWidget {
  const _BatchesTab({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = [
      for (final course in courses)
        for (final batch in course.batches) (course: course, batch: batch),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: courses.isEmpty
              ? null
              : () => _openBatchEditor(context, ref, courses.first, null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add new batch'),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No batches yet',
            message: 'Create a course, then add classroom batches.',
          )
        else
          ...rows.map((row) {
            final batch = row.batch;
            final status = !batch.isActive
                ? 'Completed'
                : batch.startsOn.isAfter(DateTime.now())
                    ? 'Upcoming'
                    : 'Active';
            return Card(
              child: ListTile(
                title: Text(batch.label),
                subtitle: Text(
                  '${row.course.title} · $status · ${batch.seatsLeft}/${batch.capacity} seats',
                ),
                trailing: Switch(
                  value: batch.admissionsOpen && batch.isActive,
                  onChanged: (value) {
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
                  },
                ),
                onTap: () => _openBatchEditor(context, ref, row.course, batch),
              ),
            );
          }),
      ],
    );
  }
}

class _AdmissionsTab extends ConsumerWidget {
  const _AdmissionsTab({required this.admissions});

  final List<CourseDemoRegistration> admissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (admissions.isEmpty) {
      return const EmptyState(
        icon: Icons.how_to_reg_outlined,
        title: 'No admission requests',
        message: 'Trial bookings and enrollments will appear here.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: admissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = admissions[index];
        return Card(
          child: ListTile(
            title: Text(item.studentName),
            subtitle: Text(
              '${item.mobile} · ${item.preferredBatch} · ${item.status}',
            ),
            trailing: item.status == 'pending'
                ? Wrap(
                    children: [
                      TextButton(
                        onPressed: () => ref
                            .read(courseRepositoryProvider)
                            .setAdmissionStatus(
                              registrationId: item.id,
                              status: 'cancelled',
                            )
                            .then(
                                (_) => ref.invalidate(ownerAdmissionsProvider)),
                        child: const Text('Reject'),
                      ),
                      FilledButton(
                        onPressed: () => ref
                            .read(courseRepositoryProvider)
                            .setAdmissionStatus(
                              registrationId: item.id,
                              status: 'contacted',
                            )
                            .then(
                                (_) => ref.invalidate(ownerAdmissionsProvider)),
                        child: const Text('Approve'),
                      ),
                    ],
                  )
                : Text(item.status),
          ),
        );
      },
    );
  }
}

class _FacultyTab extends ConsumerWidget {
  const _FacultyTab({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faculty = [
      for (final course in courses) ...course.faculty,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: courses.isEmpty
              ? null
              : () => _addFaculty(context, ref, courses.first),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add instructor'),
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
              child: ListTile(
                title: Text(item.name),
                subtitle: Text(
                  [
                    if (item.role.isNotEmpty) item.role,
                    if (item.bio.isNotEmpty) item.bio,
                  ].join(' · '),
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
        Text(institute.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(institute.address.isEmpty ? 'No address yet' : institute.address),
        Text(institute.city),
        Text(institute.phone),
        const SizedBox(height: 16),
        const Text('Classroom amenities'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
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
}

Future<void> _addFaculty(
  BuildContext context,
  WidgetRef ref,
  Course course,
) async {
  final name = TextEditingController();
  final role = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add instructor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: role,
            decoration: const InputDecoration(labelText: 'Qualifications'),
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
    ),
  );
  if (saved != true || name.text.trim().isEmpty) return;
  await ref.read(ownerCourseControllerProvider).addFaculty(
        courseId: course.id,
        name: name.text.trim(),
        role: role.text.trim(),
      );
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
            title: Text(existing == null ? 'Add batch' : 'Edit batch'),
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
                    TextField(
                      controller: subject,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    DropdownButtonFormField<EducationCategory>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: EducationCategory.values
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
                    TextField(
                      controller: timing,
                      decoration: const InputDecoration(
                        labelText: 'Timings',
                        hintText: '06:00 AM - 08:00 AM',
                      ),
                    ),
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
                    TextField(
                      controller: fee,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Course fee (INR)'),
                    ),
                    TextField(
                      controller: capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maximum seat capacity',
                      ),
                    ),
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
