import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/integration.dart';
import '../domain/integration_adapter.dart';
import '../infrastructure/unavailable_integration_adapter.dart';

final integrationAdaptersProvider = Provider<List<IntegrationAdapter>>((ref) {
  return [
    UnavailableIntegrationAdapter(
      id: 'sms',
      name: 'SMS delivery',
      category: 'Authentication',
      provider: 'Not configured',
      reason: 'A production SMS provider is not configured for this project.',
    ),
    UnavailableIntegrationAdapter(
      id: 'email',
      name: 'Transactional email',
      category: 'Authentication',
      provider: 'Supabase Auth SMTP',
      health: IntegrationHealth.unavailable,
      reason:
          'SMTP credentials and delivery health are managed by Supabase and are not readable by the app.',
    ),
    UnavailableIntegrationAdapter(
      id: 'mcp',
      name: 'MCP connectors',
      category: 'External automation',
      provider: 'Not configured',
      reason: 'No authenticated MCP server is connected to this project.',
    ),
    UnavailableIntegrationAdapter(
      id: 'crm',
      name: 'CRM',
      category: 'External automation',
      provider: 'Not configured',
      reason: 'No authenticated CRM connector is configured.',
    ),
  ];
});

final integrationHealthProvider =
    FutureProvider<List<IntegrationInfo>>((ref) async {
  final adapters = ref.watch(integrationAdaptersProvider);
  final results = <IntegrationInfo>[];
  for (final adapter in adapters) {
    final health = await adapter.healthCheck();
    final info = adapter.info;
    results.add(
      IntegrationInfo(
        id: info.id,
        name: info.name,
        category: info.category,
        provider: info.provider,
        health: health,
        detail: info.detail,
        enabled: info.enabled,
        lastChecked: DateTime.now(),
      ),
    );
  }
  return results;
});
