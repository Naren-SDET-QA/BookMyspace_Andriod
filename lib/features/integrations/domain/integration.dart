/// Operational state for an external or platform integration.
enum IntegrationHealth {
  healthy,
  degraded,
  unavailable,
  notConfigured,
}

class IntegrationInfo {
  const IntegrationInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.provider,
    required this.health,
    required this.detail,
    this.enabled = false,
    this.lastChecked,
  });

  final String id;
  final String name;
  final String category;
  final String provider;
  final IntegrationHealth health;
  final String detail;
  final bool enabled;
  final DateTime? lastChecked;
}
