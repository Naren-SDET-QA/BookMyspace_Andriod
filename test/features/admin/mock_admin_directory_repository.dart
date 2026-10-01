import 'package:bookmyspace/features/admin/domain/admin_directory.dart';
import 'package:bookmyspace/features/admin/domain/admin_directory_repository.dart';
import 'package:bookmyspace/features/courses/domain/course.dart';
import 'package:bookmyspace/features/events/domain/event.dart';
import 'package:bookmyspace/features/support/domain/support_ticket.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';

class MockAdminDirectoryRepository implements AdminDirectoryRepository {
  MockAdminDirectoryRepository({
    this.users = const [],
    this.owners = const [],
    this.venues = const [],
    this.events = const [],
    this.courses = const [],
    this.tickets = const [],
  });

  final List<AdminUserRecord> users;
  final List<AdminOwnerRecord> owners;
  final List<AdminVenueRecord> venues;
  final List<Event> events;
  final List<Course> courses;
  final List<SupportTicket> tickets;

  @override
  Future<List<AdminUserRecord>> listUsers({int limit = 100}) async => users;

  @override
  Future<List<AdminOwnerRecord>> listOwners({int limit = 100}) async => owners;

  @override
  Future<List<AdminVenueRecord>> listVenues({int limit = 100}) async => venues;

  @override
  Future<List<Event>> listPublishedEvents({int limit = 50}) async => events;

  @override
  Future<List<Course>> listPublishedCourses({int limit = 50}) async => courses;

  @override
  Future<List<SupportTicket>> listSupportTickets({int limit = 100}) async =>
      tickets;

  bool failResolve = false;
  final resolvedIds = <String>[];

  @override
  Future<SupportTicket> resolveTicket(String ticketId) async {
    resolvedIds.add(ticketId);
    if (failResolve) {
      throw Exception('not authorized');
    }
    return SupportTicket(
      id: ticketId,
      subject: 'Resolved',
      description: 'Resolved by admin',
      category: 'general',
      priority: TicketPriority.medium,
      status: TicketStatus.resolved,
    );
  }

  @override
  Future<List<Venue>> inspectableVenues({int limit = 100}) async => const [];
}
