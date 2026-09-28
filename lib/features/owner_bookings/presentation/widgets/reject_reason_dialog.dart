import 'package:flutter/material.dart';

/// Preset rejection reasons offered as quick-pick chips.
const List<String> kBookingRejectionPresets = [
  'Slot unavailable due to prior commitment',
  'Venue under maintenance',
  'Requested date is a blackout date',
  'Guest count exceeds venue capacity',
  'Incomplete booking details',
];

/// Asks for a (required) rejection reason. Resolves to the trimmed reason,
/// or null when dismissed.
///
/// Picking a preset chip fills the text field, which stays editable.
Future<String?> showRejectReasonDialog(
  BuildContext context, {
  String title = 'Reject booking',
  String message =
      'Tell the customer why this booking is being declined. '
      'The reason is shared with them.',
  String confirmLabel = 'Reject',
  List<String> presets = kBookingRejectionPresets,
  String? initialReason,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => RejectReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      presets: presets,
      initialReason: initialReason,
    ),
  );
}

class RejectReasonDialog extends StatefulWidget {
  const RejectReasonDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.presets,
    this.initialReason,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final List<String> presets;
  final String? initialReason;

  static const reasonFieldKey = Key('reject-reason-field');
  static const confirmKey = Key('reject-reason-confirm');
  static Key presetKey(int index) => Key('reject-reason-preset-$index');

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialReason ?? '',
  );
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _controller.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < widget.presets.length; i++)
                  ChoiceChip(
                    key: RejectReasonDialog.presetKey(i),
                    label: Text(
                      widget.presets[i],
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: current == widget.presets[i],
                    onSelected: (_) => setState(() {
                      _controller.text = widget.presets[i];
                      _showError = false;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: RejectReasonDialog.reasonFieldKey,
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _showError = false),
              decoration: InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Venue booked for private maintenance',
                border: const OutlineInputBorder(),
                errorText: _showError ? 'Please enter a reason' : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: RejectReasonDialog.confirmKey,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
