import 'package:bookmyspace/features/admin/domain/audit_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps deployed audit_logs columns', () {
    final entry = AuditLogEntry.fromJson({
      'id': 'log-1',
      'user_id': 'user-1',
      'action': 'venue.updated',
      'entity_type': 'venue',
      'entity_id': 'venue-1',
      'details': {'source': 'owner'},
      'ip_address': '127.0.0.1',
      'created_at': '2026-09-11T08:00:00Z',
    });

    expect(entry.actorId, 'user-1');
    expect(entry.action, 'venue.updated');
    expect(entry.entityType, 'venue');
    expect(entry.details['source'], 'owner');
    expect(entry.createdAt?.toUtc().year, 2026);
  });

  test('prefers actor_id and supports legacy metadata payloads', () {
    final entry = AuditLogEntry.fromJson({
      'id': 'log-2',
      'actor_id': 'actor-1',
      'action': 'user.updated',
      'metadata': {'source': 'legacy'},
    });

    expect(entry.actorId, 'actor-1');
    expect(entry.metadata['source'], 'legacy');
    expect(entry.createdAt, isNull);
  });
}
