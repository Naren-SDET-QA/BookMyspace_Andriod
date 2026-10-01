import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../booking/domain/booking.dart';
import '../../../calendar/presentation/calendar_export_service.dart';
import '../pass_pdf.dart';

/// Calendar, WhatsApp, and PDF actions for a confirmed entry pass.
///
/// Each control is at least 48px tall and uses the platform share sheet on
/// iOS and Android, or the browser on web.
class PassActions extends StatelessWidget {
  const PassActions({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 420;
    final buttons = [
      _Action(
        key: const Key('pass-action-calendar'),
        icon: Icons.event_outlined,
        label: 'Add to calendar',
        onPressed: () => _calendar(context),
      ),
      _Action(
        key: const Key('pass-action-whatsapp'),
        icon: Icons.chat_outlined,
        label: 'WhatsApp',
        onPressed: () => _whatsApp(context),
      ),
      _Action(
        key: const Key('pass-action-download'),
        icon: Icons.picture_as_pdf_outlined,
        label: 'Download pass',
        onPressed: () => _pdf(context),
      ),
    ];
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final button in buttons) ...[button, const SizedBox(height: 8)],
        ],
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Future<void> _calendar(BuildContext context) async {
    final message = await const CalendarExportService().exportBooking(booking);
    if (!context.mounted) return;
    _snack(context, message);
  }

  Future<void> _whatsApp(BuildContext context) async {
    final ref = booking.bookingRef.isEmpty ? booking.id : booking.bookingRef;
    final place = booking.venueCity.isEmpty
        ? booking.venueName
        : '${booking.venueName}, ${booking.venueCity}';
    final text = [
      'BookMySpace entry pass',
      place,
      '${booking.bookDate.toIso8601String().split('T').first} '
          '${booking.displayStart}–${booking.displayEnd}',
      if (booking.slotLabel.isNotEmpty) booking.slotLabel,
      'Ref $ref',
      'Show this pass at the venue entrance.',
    ].join('\n');
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _snack(context, 'Could not open WhatsApp.');
      }
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not open WhatsApp.');
    }
  }

  Future<void> _pdf(BuildContext context) async {
    try {
      final bytes = await buildPassPdf(booking);
      final name = booking.bookingRef.isEmpty
          ? 'bookmyspace-pass.pdf'
          : 'bookmyspace-${booking.bookingRef}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Could not prepare the pass PDF.');
      }
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    );
  }
}
