import 'package:flutter/material.dart';

import 'ai_booking_conversation.dart';

/// The assistant as a modal bottom sheet, opened from the Home card.
///
/// Chrome only — the conversation itself lives in [AiBookingConversation] so
/// the sheet and the Assistant tab cannot drift apart.
class AiBookingSheet extends StatelessWidget {
  const AiBookingSheet({super.key, this.initialText});

  /// Optional opening question, so a Home card can deep-link into an answer.
  final String? initialText;

  static Future<void> show(BuildContext context, {String? initialText}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiBookingSheet(initialText: initialText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 18,
          right: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: AiBookingConversation(
          initialText: initialText,
          onClose: () => Navigator.of(context).pop(),
          leading: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
