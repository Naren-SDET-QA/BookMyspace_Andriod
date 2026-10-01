import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/course.dart';
import '../course_providers.dart';
import '../widgets/course_upload_field.dart';
import '../widgets/external_link.dart';

/// Owner create/edit course form with draft-vs-publish, demo configuration,
/// media uploads, batches and faculty. Owners only ever see institutes they
/// manage (RLS + [ownerInstitutesProvider]).
class OwnerCourseEditorScreen extends ConsumerStatefulWidget {
  const OwnerCourseEditorScreen({super.key, this.existing});

  final Course? existing;

  @override
  ConsumerState<OwnerCourseEditorScreen> createState() =>
      _OwnerCourseEditorScreenState();
}

class _OwnerCourseEditorScreenState
    extends ConsumerState<OwnerCourseEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _instructor = TextEditingController();
  final _duration = TextEditingController();
  final _fee = TextEditingController();
  final _discount = TextEditingController();
  final _externalUrl = TextEditingController();
  final _contactPhone = TextEditingController();

  // Stable upload folder id even before the course row exists.
  late final String _uploadEntityId =
      widget.existing?.id ?? 'draft-${DateTime.now().microsecondsSinceEpoch}';

  String? _instituteId;
  CourseMode _mode = CourseMode.offline;
  final Set<CourseDemoMethod> _demoMethods = {};
  String _demoVideoUrl = '';
  String _demoThumbnailUrl = '';
  String _brochureUrl = '';

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _title.text = c.title;
      _description.text = c.description;
      _instructor.text = c.instructorName;
      _duration.text = '${c.durationWeeks}';
      _fee.text = c.feeAmount.toStringAsFixed(0);
      _discount.text = c.discountAmount.toStringAsFixed(0);
      _externalUrl.text = c.externalRegistrationUrl;
      _contactPhone.text = c.contactPhone;
      _instituteId = c.instituteId;
      _mode = c.mode;
      _demoMethods.addAll(c.demoMethods);
      _demoVideoUrl = c.demoVideoUrl;
      _demoThumbnailUrl = c.demoThumbnailUrl;
      _brochureUrl = c.brochureUrl;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _instructor.dispose();
    _duration.dispose();
    _fee.dispose();
    _discount.dispose();
    _externalUrl.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _save({required bool publish}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_instituteId == null) {
      setState(() => _error = 'Select an institute.');
      return;
    }
    // Validate external link only when the method is enabled.
    if (_demoMethods.contains(CourseDemoMethod.externalLink) &&
        !isSafeExternalUrl(_externalUrl.text)) {
      setState(() => _error = 'Enter a valid https registration link.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(ownerCourseControllerProvider).saveCourse(
            courseId: widget.existing?.id,
            instituteId: _instituteId!,
            title: _title.text.trim(),
            description: _description.text.trim(),
            mode: _mode,
            durationWeeks: int.tryParse(_duration.text.trim()) ?? 1,
            feeAmount: double.tryParse(_fee.text.trim()) ?? 0,
            instructorName: _instructor.text.trim(),
            discountAmount: double.tryParse(_discount.text.trim()) ?? 0,
            demoMethods: _demoMethods.toList(),
            demoVideoUrl: _demoVideoUrl,
            demoThumbnailUrl: _demoThumbnailUrl,
            brochureUrl: _brochureUrl,
            externalRegistrationUrl: _externalUrl.text.trim(),
            contactPhone: _contactPhone.text.trim(),
            publish: publish,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(publish ? 'Course published.' : 'Draft saved.'),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final id = widget.existing?.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save a draft before previewing.')),
      );
      return;
    }
    context.push(AppRoutes.courseDetails.replaceAll(':id', id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final institutesAsync = ref.watch(ownerInstitutesProvider);
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit course' : 'New course'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            institutesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load institutes: $e'),
              data: (institutes) {
                if (institutes.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'You do not manage any institute yet. Ask an '
                        'administrator to link your organization to an '
                        'institute before creating courses.',
                      ),
                    ),
                  );
                }
                _instituteId ??= institutes.first.id;
                return DropdownButtonFormField<String>(
                  initialValue: _instituteId,
                  decoration: const InputDecoration(labelText: 'Institute'),
                  items: [
                    for (final i in institutes)
                      DropdownMenuItem(value: i.id, child: Text(i.name)),
                  ],
                  onChanged: (v) => setState(() => _instituteId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Course title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CourseMode>(
                    initialValue: _mode,
                    decoration: const InputDecoration(labelText: 'Mode'),
                    items: [
                      DropdownMenuItem(
                          value: CourseMode.online,
                          child: Text(l10n.modeOnline)),
                      DropdownMenuItem(
                          value: CourseMode.offline,
                          child: Text(l10n.modeOffline)),
                      DropdownMenuItem(
                          value: CourseMode.hybrid,
                          child: Text(l10n.modeHybrid)),
                    ],
                    onChanged: (v) =>
                        setState(() => _mode = v ?? CourseMode.offline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Duration (weeks)'),
                    validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) > 0
                        ? null
                        : 'Required',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fee,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Fee (₹)'),
                    validator: (v) =>
                        (double.tryParse((v ?? '').trim()) ?? -1) >= 0
                            ? null
                            : 'Required',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _discount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Discount (₹)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructor,
              decoration: const InputDecoration(labelText: 'Instructor name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact phone'),
            ),
            const SizedBox(height: 24),
            Text(l10n.demoAndRegistration,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in CourseDemoMethod.values)
                  FilterChip(
                    label: Text(method.label),
                    selected: _demoMethods.contains(method),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _demoMethods.add(method);
                      } else {
                        _demoMethods.remove(method);
                      }
                    }),
                  ),
              ],
            ),
            if (_demoMethods.contains(CourseDemoMethod.externalLink) ||
                _demoMethods.contains(CourseDemoMethod.scheduledLive)) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _externalUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'External registration link (https)',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  return isSafeExternalUrl(value) ? null : 'Invalid URL';
                },
              ),
            ],
            if (_demoMethods.contains(CourseDemoMethod.uploadedVideo) ||
                _demoMethods.contains(CourseDemoMethod.recordedPreview)) ...[
              const SizedBox(height: 12),
              CourseUploadField(
                label: 'Demo video',
                kind: UploadKind.video,
                folder: 'demo-videos',
                entityId: _uploadEntityId,
                initialUrl: _demoVideoUrl,
                icon: Icons.videocam_rounded,
                onChanged: (url) => setState(() => _demoVideoUrl = url),
              ),
            ],
            if (_demoMethods.contains(CourseDemoMethod.uploadedBrochure)) ...[
              const SizedBox(height: 12),
              CourseUploadField(
                label: 'Brochure / sample (PDF)',
                kind: UploadKind.document,
                folder: 'brochures',
                entityId: _uploadEntityId,
                initialUrl: _brochureUrl,
                icon: Icons.picture_as_pdf_outlined,
                onChanged: (url) => setState(() => _brochureUrl = url),
              ),
            ],
            const SizedBox(height: 12),
            CourseUploadField(
              label: 'Cover / thumbnail image',
              kind: UploadKind.image,
              folder: 'course-covers',
              entityId: _uploadEntityId,
              initialUrl: _demoThumbnailUrl,
              icon: Icons.image_rounded,
              onChanged: (url) => setState(() => _demoThumbnailUrl = url),
            ),
            if (isEdit) ...[
              const SizedBox(height: 24),
              _BatchManager(course: widget.existing!),
              const SizedBox(height: 16),
              _FacultyManager(course: widget.existing!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _save(publish: false),
                    child: const Text('Save draft'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _preview,
                    child: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _save(publish: true),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.violet),
                    child: Text(_busy ? l10n.loading : 'Publish'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BatchManager extends ConsumerStatefulWidget {
  const _BatchManager({required this.course});

  final Course course;

  @override
  ConsumerState<_BatchManager> createState() => _BatchManagerState();
}

class _BatchManagerState extends ConsumerState<_BatchManager> {
  final _label = TextEditingController();
  final _capacity = TextEditingController(text: '20');
  DateTime _startsOn = DateTime.now().add(const Duration(days: 7));
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_label.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(ownerCourseControllerProvider).saveBatch(
            courseId: widget.course.id,
            label: _label.text.trim(),
            startsOn: _startsOn,
            capacity: int.tryParse(_capacity.text.trim()) ?? 0,
          );
      if (mounted) {
        _label.clear();
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(courseDetailProvider(widget.course.id));
    final batches = detail.valueOrNull?.batches ?? widget.course.batches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Batches',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final b in batches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(b.label),
            subtitle: Text(
              '${DateFormat.yMMMd().format(b.startsOn)} • capacity ${b.capacity}'
              '${b.isActive ? '' : ' • inactive'}',
            ),
            trailing: Text('${b.seatsLeft} seats left'),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _label,
          decoration: const InputDecoration(labelText: 'Batch label'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startsOn,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) setState(() => _startsOn = picked);
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(DateFormat.yMMMd().format(_startsOn)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add batch'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
          ),
        ),
      ],
    );
  }
}

class _FacultyManager extends ConsumerStatefulWidget {
  const _FacultyManager({required this.course});

  final Course course;

  @override
  ConsumerState<_FacultyManager> createState() => _FacultyManagerState();
}

class _FacultyManagerState extends ConsumerState<_FacultyManager> {
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _bio = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(ownerCourseControllerProvider).addFaculty(
            courseId: widget.course.id,
            name: _name.text.trim(),
            role: _role.text.trim(),
            bio: _bio.text.trim(),
          );
      if (mounted) {
        _name.clear();
        _role.clear();
        _bio.clear();
        setState(() => _busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(courseDetailProvider(widget.course.id));
    final faculty = detail.valueOrNull?.faculty ?? widget.course.faculty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Faculty',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final f in faculty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.person_rounded, color: AppTheme.violet),
            title: Text(f.name),
            subtitle: f.role.isNotEmpty ? Text(f.role) : null,
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Faculty name'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _role,
          decoration: const InputDecoration(labelText: 'Role'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bio,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Bio'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add faculty'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
          ),
        ),
      ],
    );
  }
}
