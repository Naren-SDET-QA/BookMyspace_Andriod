/// Platform-wide maintenance switch and broadcast banner, stored in the
/// global `module_feature_configs` row `platform_status`.
class PlatformStatus {
  const PlatformStatus({
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
    this.broadcastEnabled = false,
    this.broadcastMessage = '',
    this.broadcastSeverity = 'info',
  });

  static const moduleKey = 'platform_status';
  static const none = PlatformStatus();

  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final bool broadcastEnabled;
  final String broadcastMessage;

  /// `info`, `warning` or `critical`.
  final String broadcastSeverity;

  bool get showsBroadcast =>
      broadcastEnabled && broadcastMessage.trim().isNotEmpty;

  String get maintenanceText => maintenanceMessage.trim().isNotEmpty
      ? maintenanceMessage.trim()
      : 'BookMySpace is under maintenance. Bookings are paused for now.';

  static bool _flag(Object? v) =>
      v == true || v == 'true' || v == 1 || v == '1';

  factory PlatformStatus.fromMetadata(Map<String, dynamic> m) {
    final severity = '${m['broadcast_severity'] ?? 'info'}';
    return PlatformStatus(
      maintenanceEnabled: _flag(m['maintenance_enabled']),
      maintenanceMessage: '${m['maintenance_message'] ?? ''}',
      broadcastEnabled: _flag(m['broadcast_enabled']),
      broadcastMessage: '${m['broadcast_message'] ?? ''}',
      broadcastSeverity: const {'info', 'warning', 'critical'}.contains(severity)
          ? severity
          : 'info',
    );
  }

  Map<String, dynamic> toMetadata() => {
        'maintenance_enabled': maintenanceEnabled,
        'maintenance_message': maintenanceMessage.trim(),
        'broadcast_enabled': broadcastEnabled,
        'broadcast_message': broadcastMessage.trim(),
        'broadcast_severity': broadcastSeverity,
      };
}
