import '../../venues/domain/venue.dart';
import '../../events/domain/event.dart';
import '../../courses/domain/course.dart';
import '../../support/domain/support_ticket.dart';
import 'admin_directory.dart';

/// Read-only admin directory backed by existing tables and RLS.
abstract interface class AdminDirectoryRepository {
  Future<List<AdminUserRecord>> listUsers({int limit = 100});

  Future<List<AdminOwnerRecord>> listOwners({int limit = 100});

  Future<List<AdminVenueRecord>> listVenues({int limit = 100});

  Future<List<Event>> listPublishedEvents({int limit = 50});

  Future<List<Course>> listPublishedCourses({int limit = 50});

  Future<List<SupportTicket>> listSupportTickets({int limit = 100});

  Future<SupportTicket> resolveTicket(String ticketId);

  Future<List<Venue>> inspectableVenues({int limit = 100});
}
