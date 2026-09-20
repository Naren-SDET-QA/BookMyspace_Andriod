import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/course.dart';
import '../course_providers.dart';

Future<void> showClassEnrollmentSheet(
  BuildContext context, {
  required Course course,
  required CourseBatch batch,
  required bool isTrial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _EnrollmentForm(
        course: course,
        batch: batch,
        isTrial: isTrial,
      ),
    ),
  );
}

class _EnrollmentForm extends ConsumerStatefulWidget {
  const _EnrollmentForm({
    required this.course,
    required this.batch,
    required this.isTrial,
  });

  final Course course;
  final CourseBatch batch;
  final bool isTrial;

  @override
  ConsumerState<_EnrollmentForm> createState() => _EnrollmentFormState();
}

class _EnrollmentFormState extends ConsumerState<_EnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  DateTime _start = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (ref.read(currentUserProvider) == null) {
      Navigator.pop(context);
      if (!context.mounted) return;
      context.push(AppRoutes.login);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final record = await ref.read(courseEnrollmentControllerProvider).enroll(
            courseId: widget.course.id,
            batchId: widget.batch.id,
            isTrial: widget.isTrial,
            studentName: _name.text.trim(),
            contactPhone: _phone.text.trim(),
            preferredStart: _start,
          );
      if (!mounted) return;
      Navigator.pop(context);
      await showEnrollmentVoucherDialog(
        context,
        course: widget.course,
        batch: widget.batch,
        record: record,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isTrial ? 'Book Free Trial' : 'Enroll Now';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${widget.course.title} · ${widget.batch.label}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Student name'),
                validator: (value) => (value == null || value.trim().length < 2)
                    ? 'Enter the student name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact number'),
                validator: (value) => (value == null || value.trim().length < 8)
                    ? 'Enter a contact number'
                    : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Preferred batch start'),
                subtitle: Text(DateFormat.yMMMd().format(_start)),
                trailing: const Icon(Icons.event_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _start = picked);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(title),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showEnrollmentVoucherDialog(
  BuildContext context, {
  required Course course,
  required CourseBatch batch,
  required CourseEnrollmentRecord record,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final code =
          record.admissionCode.isEmpty ? record.id : record.admissionCode;
      return AlertDialog(
        title: Text(record.isTrial ? 'Trial booked' : 'Admission confirmed'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admission ID',
                  style: Theme.of(context).textTheme.labelMedium),
              SelectableText(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.violetSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 96),
                    const SizedBox(height: 8),
                    Text(
                      'Batch pass · $code',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (course.instituteName.isNotEmpty) Text(course.instituteName),
              if (course.instituteCity.isNotEmpty) Text(course.instituteCity),
              if (course.contactPhone.isNotEmpty)
                Text('Faculty contact: ${course.contactPhone}'),
              if (course.instructorName.isNotEmpty)
                Text('Instructor: ${course.instructorName}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
            },
            child: const Text('Copy ID'),
          ),
          TextButton(
            onPressed: () {
              final start = batch.startsOn.toUtc();
              final end = start.add(const Duration(hours: 2));
              final uri = Uri.parse(
                'https://calendar.google.com/calendar/render?action=TEMPLATE'
                '&text=${Uri.encodeComponent(course.title)}'
                '&dates=${_cal(start)}/${_cal(end)}',
              );
              launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Add reminder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

String _cal(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}00Z';
}
