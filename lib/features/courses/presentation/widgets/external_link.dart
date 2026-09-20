import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result of an attempt to open an external registration/demo link.
enum ExternalLinkOutcome { opened, cancelled, invalid, failed }

/// Validates an absolute http(s) URL. Relative URLs, `javascript:`, `file:`,
/// `data:` and other schemes are rejected so a misconfigured admin link can
/// never navigate the web view somewhere unsafe.
bool isSafeExternalUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  if (!uri.isAbsolute) return false;
  if (uri.hasEmptyPath && uri.host.isEmpty) return false;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'https' || scheme == 'http') && uri.host.isNotEmpty;
}

/// Opens [raw] in the external browser after an explicit user confirmation
/// that they are leaving the app. No personal information is transmitted; the
/// URL is opened exactly as configured by the admin.
///
/// Returns [ExternalLinkOutcome.invalid] for unsafe/malformed URLs without
/// showing the dialog, and [ExternalLinkOutcome.cancelled] if the user backs
/// out.
Future<ExternalLinkOutcome> confirmAndOpenExternalUrl(
  BuildContext context, {
  required String raw,
  required String courseTitle,
  required String instituteName,
}) async {
  if (!isSafeExternalUrl(raw)) return ExternalLinkOutcome.invalid;
  final uri = Uri.parse(raw.trim());

  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('You are leaving BookMySpace'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This opens the registration page for "$courseTitle"'
            '${instituteName.isEmpty ? '' : ' at $instituteName'} in your '
            'browser. BookMySpace does not send any of your personal '
            'information to this site.',
          ),
          const SizedBox(height: 12),
          SelectableText(
            uri.toString(),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Open link'),
        ),
      ],
    ),
  );
  if (proceed != true) return ExternalLinkOutcome.cancelled;

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  return ok ? ExternalLinkOutcome.opened : ExternalLinkOutcome.failed;
}

/// Opens a `tel:` or WhatsApp deep link for contacting an institute.
Future<bool> openContactLink(String raw) async {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  Uri uri;
  if (trimmed.startsWith('http')) {
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !isSafeExternalUrl(trimmed)) return false;
    uri = parsed;
  } else {
    // Bare phone number -> tel: link.
    final digits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return false;
    uri = Uri(scheme: 'tel', path: digits);
  }
  return launchUrl(uri);
}

/// Opens a WhatsApp chat for [phone] (digits, optional leading `+`).
Future<bool> openWhatsApp(String phone) async {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return false;
  final uri = Uri.parse('https://wa.me/$digits');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens a demo video / brochure / recorded preview URL. These are trusted
/// admin-uploaded media links, so they open directly (no leaving-the-app
/// confirmation) but still must be safe absolute http(s) URLs.
Future<bool> openMediaUrl(String raw) async {
  if (!isSafeExternalUrl(raw)) return false;
  return launchUrl(Uri.parse(raw.trim()), mode: LaunchMode.externalApplication);
}
