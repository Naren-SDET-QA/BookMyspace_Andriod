import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/domain/app_role.dart';
import '../../../auth/presentation/role_providers.dart';
import '../../../integrations/domain/integration.dart';
import '../../../integrations/presentation/integration_providers.dart';

/// Connector health plus the real admin surfaces for API keys and webhooks.
/// Calendar export stays on a confirmed booking receipt.
class ConnectedAppsScreen extends ConsumerWidget {
  const ConnectedAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final health = ref.watch(integrationHealthProvider);
    final roles = ref.watch(currentUserRolesProvider).valueOrNull ?? {};
    final isAdmin = roles.canViewAdminTools;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Connected Apps & Developer APIs'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'MCP connectors, REST API keys, webhooks, and deep links. A confirmed booking can export a calendar file from its receipt.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          health.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('Could not read connector status: $error'),
            data: (items) => Column(
              children: [
                for (final item in items) _IntegrationTile(item: item),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Calendar (.ics) and receipts'),
            subtitle: const Text(
              'Open My Bookings, then export a calendar file from a confirmed receipt.',
            ),
            onTap: () => context.push(AppRoutes.bookings),
          ),
          if (isAdmin) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.vpn_key_outlined),
              title: const Text('API keys, webhooks, and delivery log'),
              subtitle: const Text(
                'Create scoped keys and inspect webhook deliveries.',
              ),
              onTap: () => context.push(AppRoutes.adminDeveloperPlatform),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Connector registry'),
              subtitle: const Text(
                'Google Calendar, WhatsApp, Slack, and custom sites.',
              ),
              onTap: () => context.push(AppRoutes.adminConnectorRegistry),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({required this.item});

  final IntegrationInfo item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (item.health) {
      IntegrationHealth.healthy => 'Connected',
      IntegrationHealth.degraded => 'Degraded',
      IntegrationHealth.unavailable => 'Unavailable',
      IntegrationHealth.notConfigured => 'Not configured',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.name),
      subtitle: Text('${item.category} · ${item.provider}\n${item.detail}'),
      isThreeLine: true,
      trailing: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
