import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

/// Phase-1 content entry point backed by the existing PROD admin surfaces.
///
/// The Phase-1 branch had a separate CMS screen coupled to prototype-only
/// theme APIs. PROD already owns the runtime configuration, app-section,
/// promotion, and listing-field screens, so this hub exposes those stable
/// screens without replacing the admin architecture.
class AdminContentScreen extends StatelessWidget {
  const AdminContentScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Content & configuration')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Manage customer-facing content using the existing production admin controls.',
        ),
        const SizedBox(height: 12),
        const _ContentLink(
          icon: Icons.view_agenda_outlined,
          title: 'Home sections',
          subtitle: 'Control which customer sections are visible.',
          route: AppRoutes.adminAppSections,
        ),
        const _ContentLink(
          icon: Icons.local_offer_outlined,
          title: 'Promotions',
          subtitle: 'Create and schedule offers.',
          route: AppRoutes.adminPromotions,
        ),
        const _ContentLink(
          icon: Icons.tune_outlined,
          title: 'Runtime settings',
          subtitle: 'Manage tenant branding and feature visibility.',
          route: AppRoutes.adminSettings,
        ),
        const _ContentLink(
          icon: Icons.dynamic_form_outlined,
          title: 'Listing fields',
          subtitle: 'Configure venue fields by category.',
          route: AppRoutes.adminListingFields,
        ),
      ],
    ),
  );
}

class _ContentLink extends StatelessWidget {
  const _ContentLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}
