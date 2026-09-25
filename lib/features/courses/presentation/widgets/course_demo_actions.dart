import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/course.dart';
import 'external_link.dart';
import 'register_demo_sheet.dart';

/// Renders one action button per admin-configured, actionable demo method.
///
/// A method only produces a button when the data it needs is present (e.g. an
/// external link is only shown when [Course.externalRegistrationUrl] is a valid
/// URL), so the row never displays empty labels or dead buttons. If no methods
/// are configured, the widget renders nothing.
class CourseDemoActions extends StatelessWidget {
  const CourseDemoActions({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final actions = _resolveActions(context);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final action in actions)
          _DemoActionButton(
            icon: action.icon,
            label: action.label,
            filled: action.filled,
            onTap: action.onTap,
          ),
      ],
    );
  }

  List<_DemoAction> _resolveActions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = <_DemoAction>[];

    for (final method in course.demoMethods) {
      switch (method) {
        case CourseDemoMethod.internalForm:
          actions.add(_DemoAction(
            icon: Icons.event_available_rounded,
            label: method.label,
            filled: true,
            onTap: () => showRegisterDemoSheet(context, course: course),
          ));
        case CourseDemoMethod.externalLink:
          if (!isSafeExternalUrl(course.externalRegistrationUrl)) break;
          actions.add(_DemoAction(
            icon: Icons.open_in_new_rounded,
            label: method.label,
            onTap: () => confirmAndOpenExternalUrl(
              context,
              raw: course.externalRegistrationUrl,
              courseTitle: course.title,
              instituteName: course.instituteName,
            ),
          ));
        case CourseDemoMethod.phoneWhatsApp:
          final contact =
              course.contactPhone.isNotEmpty ? course.contactPhone : null;
          if (contact == null) break;
          actions.add(_DemoAction(
            icon: Icons.chat_rounded,
            label: l10n.contactInstitute,
            onTap: () => _contact(context, contact, messenger),
          ));
        case CourseDemoMethod.uploadedVideo:
        case CourseDemoMethod.recordedPreview:
          if (course.demoVideoUrl.isEmpty) break;
          actions.add(_DemoAction(
            icon: Icons.play_circle_outline_rounded,
            label: method.label,
            filled: true,
            onTap: () => openMediaUrl(course.demoVideoUrl),
          ));
        case CourseDemoMethod.uploadedBrochure:
          if (course.brochureUrl.isEmpty) break;
          actions.add(_DemoAction(
            icon: Icons.picture_as_pdf_outlined,
            label: method.label,
            onTap: () => openMediaUrl(course.brochureUrl),
          ));
        case CourseDemoMethod.scheduledLive:
          if (course.externalRegistrationUrl.isEmpty) break;
          actions.add(_DemoAction(
            icon: Icons.videocam_rounded,
            label: method.label,
            onTap: () => confirmAndOpenExternalUrl(
              context,
              raw: course.externalRegistrationUrl,
              courseTitle: course.title,
              instituteName: course.instituteName,
            ),
          ));
        case CourseDemoMethod.noDemo:
          break;
      }
    }
    return actions;
  }

  Future<void> _contact(
    BuildContext context,
    String contact,
    ScaffoldMessengerState messenger,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_rounded),
              title: Text(contact),
              onTap: () => Navigator.pop(sheetContext, 'call'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(sheetContext, 'whatsapp'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final ok = choice == 'whatsapp'
        ? await openWhatsApp(contact)
        : await openContactLink(contact);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the contact link.')),
      );
    }
  }
}

class _DemoAction {
  const _DemoAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
}

class _DemoActionButton extends StatelessWidget {
  const _DemoActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return filled
        ? FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }
}
