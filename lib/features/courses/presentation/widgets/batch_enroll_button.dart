import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/course.dart';
import '../course_waitlist_providers.dart';
import 'class_enrollment_sheet.dart';
import 'waitlist_alert_sheet.dart';

/// Primary action for a batch: Enroll, Join waitlist, waitlist position
/// (tap to leave), or "Seat offered" once the learner is promoted.
class BatchEnrollButton extends ConsumerStatefulWidget {
  const BatchEnrollButton({
    super.key,
    required this.course,
    required this.batch,
  });

  final Course course;
  final CourseBatch batch;

  @override
  ConsumerState<BatchEnrollButton> createState() => _BatchEnrollButtonState();
}

class _BatchEnrollButtonState extends ConsumerState<BatchEnrollButton> {
  bool _busy = false;

  static final _style = FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 36),
    backgroundColor: const Color(0xFF6D28D9),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  static final _waitStyle = FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 36),
    backgroundColor: const Color(0xFFE11D48),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  void _enroll() => showClassEnrollmentSheet(
        context,
        course: widget.course,
        batch: widget.batch,
        isTrial: false,
      );

  void _join() {
    showWaitlistAlertSheet(
      context,
      course: widget.course,
      batch: widget.batch,
    );
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave waitlist?'),
        content: const Text(
          'You will lose your place in the queue for this batch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(courseWaitlistControllerProvider).leave(
            courseId: widget.course.id,
            batchId: widget.batch.id,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('You left the waitlist.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final entry =
        ref.watch(myCourseWaitlistProvider).valueOrNull?[batch.id];
    const label = TextStyle(fontSize: 12);

    if (_busy) {
      return FilledButton(
        onPressed: null,
        style: _style,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (entry != null && entry.isOffered) {
      return FilledButton.icon(
        onPressed: _enroll,
        style: _style,
        icon: const Icon(Icons.event_seat_rounded, size: 16),
        label: const Text('Seat offered', style: label),
      );
    }
    if (entry != null) {
      return OutlinedButton.icon(
        onPressed: _leave,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFB7185),
          side: const BorderSide(color: Color(0xFFFB7185)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.notifications_active_rounded, size: 16),
        label: Text('Waitlist #${entry.position}', style: label),
      );
    }
    if (batch.isFull) {
      return FilledButton.icon(
        onPressed: batch.waitlistEnabled ? _join : null,
        style: _waitStyle,
        icon: const Icon(Icons.notifications_rounded, size: 16),
        label: Text(
          batch.waitlistEnabled ? 'Notify Me' : 'Batch full',
          style: label,
        ),
      );
    }
    return FilledButton.icon(
      onPressed: _enroll,
      style: _style,
      icon: const Icon(Icons.event_available_rounded, size: 16),
      label: const Text('1-Tap Book', style: label),
    );
  }
}
