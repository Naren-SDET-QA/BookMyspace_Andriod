import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../support/domain/support_ticket.dart';
import '../../../support/presentation/support_providers.dart';
import '../../domain/venue.dart';

/// Subject used for a venue enquiry ticket (venue name + id so support can
/// route it to the owner).
String venueEnquirySubject(Venue venue) =>
    'Enquiry: ${venue.name} (${venue.id})';

/// Opens the "Send enquiry" sheet. Resolves to true once the enquiry was
/// filed as a support ticket (category `venue`).
Future<bool> showVenueEnquirySheet(BuildContext context, Venue venue) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => VenueEnquirySheet(venue: venue),
  );
  return sent ?? false;
}

class VenueEnquirySheet extends ConsumerStatefulWidget {
  const VenueEnquirySheet({super.key, required this.venue});

  final Venue venue;

  @override
  ConsumerState<VenueEnquirySheet> createState() => _VenueEnquirySheetState();
}

class _VenueEnquirySheetState extends ConsumerState<VenueEnquirySheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Please write your question');
      return;
    }
    final navigator = Navigator.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(supportTicketRepositoryProvider)
          .createTicket(
            subject: venueEnquirySubject(widget.venue),
            description:
                '$message\n\n'
                'Venue: ${widget.venue.name}\n'
                'Venue ID: ${widget.venue.id}',
            category: 'venue',
            priority: TicketPriority.medium,
          );
      ref.invalidate(myTicketsProvider);
      if (!mounted) return;
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not send your enquiry. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          key: const Key('venue_enquiry_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send enquiry',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.venue.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('venue_enquiry_message'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: 'Your question',
                hintText: 'Dates, guest count, pricing, facilities…',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('venue_enquiry_send'),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Send enquiry'),
            ),
          ],
        ),
      ),
    );
  }
}
