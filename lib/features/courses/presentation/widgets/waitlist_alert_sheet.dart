import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/course.dart';
import '../course_waitlist_providers.dart';
import 'academic_sheet.dart';

/// Joins the server waitlist. The queue is stored in the database, so the
/// same subscription works on iOS, web, and Android.
Future<void> showWaitlistAlertSheet(
  BuildContext context, {
  required Course course,
  required CourseBatch batch,
}) {
  return showAcademicSheet<void>(
    context,
    child: _WaitlistAlert(course: course, batch: batch),
  );
}

class _WaitlistAlert extends ConsumerStatefulWidget {
  const _WaitlistAlert({required this.course, required this.batch});

  final Course course;
  final CourseBatch batch;

  @override
  ConsumerState<_WaitlistAlert> createState() => _WaitlistAlertState();
}

class _WaitlistAlertState extends ConsumerState<_WaitlistAlert> {
  bool _busy = false;
  String? _error;

  String get _when {
    final start = widget.batch.startsOn;
    if (start.year <= 1971) return 'the next time a seat opens';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${start.day} ${months[start.month - 1]} ${start.year}';
  }

  Future<void> _join() async {
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
      final position = await ref.read(courseWaitlistControllerProvider).join(
            courseId: widget.course.id,
            batchId: widget.batch.id,
          );
      if (!mounted) return;
      Navigator.pop(context);
      final where = position == 0
          ? 'A seat is being held for you. Enroll to secure it.'
          : "You're on the waitlist! We will notify you immediately if a seat opens up. Your place is #$position.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(where)));
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
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final phone = user?.phone ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          'Join the waitlist',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text('${widget.course.title} · ${widget.batch.label}'),
        const SizedBox(height: 8),
        Text('Next batch start: $_when'),
        const SizedBox(height: 12),
        Text(
          phone.isEmpty
              ? 'Alerts go to the account you are signed in with, on iOS, web, and Android.'
              : 'Alerts go to $phone and the account you are signed in with.',
          style: theme.textTheme.bodyMedium,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('waitlist-confirm'),
          onPressed: _busy ? null : _join,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
          child: Text(_busy ? 'Saving…' : 'Join waitlist and notify me'),
        ),
      ],
    );
  }
}
