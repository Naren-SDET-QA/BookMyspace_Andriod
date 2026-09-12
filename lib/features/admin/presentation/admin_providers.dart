import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../courses/domain/course.dart';
import '../../events/domain/event.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/admin_directory.dart';
import '../domain/admin_directory_repository.dart';
import '../domain/audit_log_entry.dart';
import '../domain/audit_log_repository.dart';
import '../infrastructure/supabase_admin_directory_repository.dart';
import '../infrastructure/supabase_audit_repository.dart';

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return SupabaseAuditRepository(ref.watch(supabaseProvider));
});

final recentAuditLogsProvider = FutureProvider<List<AuditLogEntry>>((ref) {
  return ref.watch(auditLogRepositoryProvider).recentLogs(limit: 100);
});

final adminDirectoryRepositoryProvider =
    Provider<AdminDirectoryRepository>((ref) {
  return SupabaseAdminDirectoryRepository(ref.watch(supabaseProvider));
});

final adminUsersProvider = FutureProvider<List<AdminUserRecord>>((ref) {
  return ref.watch(adminDirectoryRepositoryProvider).listUsers();
});

final adminOwnersProvider = FutureProvider<List<AdminOwnerRecord>>((ref) {
  return ref.watch(adminDirectoryRepositoryProvider).listOwners();
});

final adminVenuesProvider = FutureProvider<List<AdminVenueRecord>>((ref) {
  return ref.watch(adminDirectoryRepositoryProvider).listVenues();
});

final adminPublishedEventsProvider = FutureProvider<List<Event>>((ref) {
  return ref.watch(adminDirectoryRepositoryProvider).listPublishedEvents();
});

final adminPublishedCoursesProvider = FutureProvider<List<Course>>((ref) {
  return ref.watch(adminDirectoryRepositoryProvider).listPublishedCourses();
});

final adminSupportTicketsProvider =
    FutureProvider<List<SupportTicket>>((ref) {
  return ref.watch(adminDirectoryRepositoryProvider).listSupportTickets();
});

final resolveSupportTicketProvider =
    FutureProvider.autoDispose.family<SupportTicket, String>((ref, ticketId) async {
  final ticket =
      await ref.watch(adminDirectoryRepositoryProvider).resolveTicket(ticketId);
  ref.invalidate(adminSupportTicketsProvider);
  return ticket;
});
