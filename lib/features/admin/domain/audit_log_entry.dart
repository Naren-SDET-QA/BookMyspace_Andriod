/// A single administrative action recorded by the backend.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    this.actorId,
    this.entityType,
    this.entityId,
    this.details = const <String, dynamic>{},
    this.ipAddress,
    this.createdAt,
  });

  final String id;
  final String action;
  final DateTime? createdAt;
  final String? actorId;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic> details;
  final String? ipAddress;

  /// Backwards-compatible name for callers that used the old model field.
  Map<String, dynamic> get metadata => details;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actorId: json['actor_id'] as String? ?? json['user_id'] as String?,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      details: Map<String, dynamic>.from(
        ((json['details'] ?? json['metadata']) as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      ),
      ipAddress: json['ip_address'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}
