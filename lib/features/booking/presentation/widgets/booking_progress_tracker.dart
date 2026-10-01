import 'package:flutter/material.dart';

import '../../domain/booking.dart';

/// Four-step host-review tracker. It reads the server status only.
///
/// Request sent → Host reviewing → Payment → Entry pass.
class BookingProgressTracker extends StatelessWidget {
  const BookingProgressTracker({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final progress = BookingReviewProgress.of(status);
    final steps = BookingReviewProgress.labels;
    return LayoutBuilder(
      key: const Key('booking-progress-tracker'),
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final tiles = [
          for (var i = 0; i < steps.length; i++)
            _StepTile(
              index: i,
              label: steps[i],
              state: progress.stateFor(i),
              wide: wide,
            ),
        ];
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final tile in tiles) Expanded(child: tile)],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: tiles,
        );
      },
    );
  }
}

enum _StepState { upcoming, current, done, failed }

class BookingReviewProgress {
  const BookingReviewProgress(this.activeIndex, {this.failed = false});

  final int activeIndex;
  final bool failed;

  static const labels = [
    'Request sent',
    'Host reviewing',
    'Payment',
    'Entry pass',
  ];

  factory BookingReviewProgress.of(BookingStatus status) {
    return switch (status) {
      BookingStatus.held ||
      BookingStatus.awaitingOwnerApproval ||
      BookingStatus.pendingOwnerApproval => const BookingReviewProgress(1),
      BookingStatus.pending => const BookingReviewProgress(2),
      BookingStatus.confirmed ||
      BookingStatus.completed => const BookingReviewProgress(3),
      BookingStatus.ownerRejected ||
      BookingStatus.rejected ||
      BookingStatus.approvalExpired ||
      BookingStatus.cancelled => const BookingReviewProgress(1, failed: true),
      BookingStatus.refunded => const BookingReviewProgress(2, failed: true),
      BookingStatus.noShow ||
      BookingStatus.unknown => const BookingReviewProgress(0),
    };
  }

  _StepState stateFor(int index) {
    if (failed && index == activeIndex) return _StepState.failed;
    if (index < activeIndex || (index == 3 && activeIndex == 3 && !failed)) {
      return _StepState.done;
    }
    if (index == activeIndex) return _StepState.current;
    return _StepState.upcoming;
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.label,
    required this.state,
    required this.wide,
  });

  final int index;
  final String label;
  final _StepState state;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = switch (state) {
      _StepState.done => (const Color(0xFF0F766E), Icons.check_rounded),
      _StepState.current => (
        theme.colorScheme.primary,
        Icons.hourglass_top_rounded,
      ),
      _StepState.failed => (theme.colorScheme.error, Icons.close_rounded),
      _StepState.upcoming => (theme.colorScheme.outline, Icons.circle_outlined),
    };
    final text = state == _StepState.failed && index == 1
        ? 'Host declined'
        : label;
    return Semantics(
      label: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  key: Key('booking-progress-step-$index'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: state == _StepState.upcoming
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    fontWeight: state == _StepState.current
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
              if (!wide && index < 3) const SizedBox(width: 0),
            ],
          ),
        ),
      ),
    );
  }
}
