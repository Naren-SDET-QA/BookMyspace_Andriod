import 'package:flutter/material.dart';

import '../../../ai_booking/presentation/widgets/ai_booking_conversation.dart';

/// The booking assistant as a first-class destination in the customer shell.
///
/// Renders the same [AiBookingConversation] the Home sheet uses, so the two
/// presentations cannot drift apart. Unlike the sheet it fills the viewport,
/// which keeps the composer pinned to the bottom instead of floating
/// mid-screen when the transcript is short.
///
/// It ships disabled. An admin turns it on from the console, and can retire a
/// destination they do not need to make room for it.
class AssistantTabScreen extends StatelessWidget {
  const AssistantTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: AiBookingConversation(fillHeight: true),
        ),
      ),
    );
  }
}
