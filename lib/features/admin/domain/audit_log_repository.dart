import 'audit_log_entry.dart';

/// Reads administrative audit events.
abstract interface class AuditLogRepository {
  Future<List<AuditLogEntry>> recentLogs({int limit = 100});
}
