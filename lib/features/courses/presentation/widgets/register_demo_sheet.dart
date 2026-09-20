import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/course.dart';
import '../course_providers.dart';

/// Shows the internal demo-registration form as a modal bottom sheet.
///
/// Only surfaced for courses whose configured [CourseDemoMethod] list contains
/// [CourseDemoMethod.internalForm]. Fields are validated client-side before the
/// request reaches the repository.
Future<void> showRegisterDemoSheet(
  BuildContext context, {
  required Course course,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      // Keep the form above the on-screen keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _RegisterDemoForm(course: course),
    ),
  );
}

class _RegisterDemoForm extends ConsumerStatefulWidget {
  const _RegisterDemoForm({required this.course});

  final Course course;

  @override
  ConsumerState<_RegisterDemoForm> createState() => _RegisterDemoFormState();
}

class _RegisterDemoFormState extends ConsumerState<_RegisterDemoForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  String? _preferredBatch;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(courseInteractionControllerProvider).registerForDemo(
            courseId: widget.course.id,
            studentName: _name.text.trim(),
            mobile: _mobile.text.trim(),
            email: _email.text.trim(),
            preferredBatch: _preferredBatch ?? '',
            note: _note.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).demoRequestSubmitted)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final batches = widget.course.batches.where((b) => b.isActive).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.registerForDemo,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                widget.course.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.studentName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.studentName : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.mobileNumber),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  return digits.length < 10 ? l10n.mobileNumber : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.email),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  return value.contains('@') ? null : l10n.email;
                },
              ),
              if (batches.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _preferredBatch,
                  decoration: InputDecoration(labelText: l10n.preferredBatch),
                  items: [
                    for (final b in batches)
                      DropdownMenuItem(value: b.id, child: Text(b.label)),
                  ],
                  onChanged: (v) => setState(() => _preferredBatch = v),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.note),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? l10n.loading : l10n.submit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
