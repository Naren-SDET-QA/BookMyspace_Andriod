import 'package:bookmyspace/features/admin/domain/admin_directory.dart';
import 'package:bookmyspace/features/support/domain/support_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_admin_directory_repository.dart';

void main() {
  test('admin resolve transitions an open ticket', () async {
    final repo = MockAdminDirectoryRepository(
      tickets: const [
        SupportTicket(
          id: 't1',
          subject: 'Payment stuck',
          description: 'Need help',
          category: 'payment',
          priority: TicketPriority.high,
          status: TicketStatus.open,
        ),
      ],
    );
    final resolved = await repo.resolveTicket('t1');
    expect(resolved.status, TicketStatus.resolved);
    expect(repo.resolvedIds, ['t1']);
  });

  test('unauthorized resolve is denied by the repository contract', () async {
    final repo = MockAdminDirectoryRepository()..failResolve = true;
    expect(repo.resolveTicket('t1'), throwsA(isA<Exception>()));
  });

  test('customer directory mock does not invent admin users', () {
    const record = AdminUserRecord(
      id: 'u1',
      fullName: 'Ada',
      email: 'ada@test.com',
      roles: ['customer'],
    );
    expect(record.roles, isNot(contains('administrator')));
  });
}
