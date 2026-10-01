import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../course_providers.dart';

/// Shows a rating + comment dialog and submits course feedback. Only callable
/// for an enrolled learner; the repository/RLS enforces that server-side and
/// any `not_enrolled` error is surfaced inline.
Future<void> showFeedbackDialog(
  BuildContext context, {
  required String courseId,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _FeedbackDialog(courseId: courseId),
  );
}

class _FeedbackDialog extends ConsumerStatefulWidget {
  const _FeedbackDialog({required this.courseId});

  final String courseId;

  @override
  ConsumerState<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<_FeedbackDialog> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_rating == 0) {
      setState(() => _error = l10n.yourRating);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(courseInteractionControllerProvider).submitFeedback(
            courseId: widget.courseId,
            rating: _rating,
            comment: _comment.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedbackSubmitted)),
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
    return AlertDialog(
      title: Text(l10n.writeFeedback),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.yourRating, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  onPressed:
                      _busy ? null : () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: star <= _rating ? Colors.amber : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.feedback,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? l10n.loading : l10n.submit),
        ),
      ],
    );
  }
}
