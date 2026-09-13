import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../integration_providers.dart';
import '../../domain/integration.dart';

class AdminIntegrationsScreen extends ConsumerWidget {
  const AdminIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrations = ref.watch(integrationHealthProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrations'),
        actions: [
          IconButton(
            tooltip: 'Refresh health',
            onPressed: () => ref.invalidate(integrationHealthProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: integrations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(integrationHealthProvider),
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: Icon(_iconFor(item.health)),
                title: Text(item.name),
                subtitle:
                    Text('${item.category} · ${item.provider}\n${item.detail}'),
                isThreeLine: true,
                trailing: Text(
                  _labelFor(item.health),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _colorFor(context, item.health),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _labelFor(IntegrationHealth health) {
    switch (health) {
      case IntegrationHealth.healthy:
        return 'Healthy';
      case IntegrationHealth.degraded:
        return 'Degraded';
      case IntegrationHealth.unavailable:
        return 'Unavailable';
      case IntegrationHealth.notConfigured:
        return 'Not configured';
    }
  }

  static IconData _iconFor(IntegrationHealth health) {
    switch (health) {
      case IntegrationHealth.healthy:
        return Icons.check_circle_outline;
      case IntegrationHealth.degraded:
        return Icons.warning_amber_outlined;
      case IntegrationHealth.unavailable:
        return Icons.error_outline;
      case IntegrationHealth.notConfigured:
        return Icons.settings_input_component_outlined;
    }
  }

  static Color _colorFor(BuildContext context, IntegrationHealth health) {
    switch (health) {
      case IntegrationHealth.healthy:
        return Colors.green;
      case IntegrationHealth.degraded:
        return Colors.orange;
      case IntegrationHealth.unavailable:
        return Theme.of(context).colorScheme.error;
      case IntegrationHealth.notConfigured:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }
}
