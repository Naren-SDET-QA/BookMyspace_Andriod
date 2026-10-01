/// Roles granted to a user by the Supabase backend.
///
/// These values mirror the `public.user_role` enum. They are intentionally
/// separate from auth user metadata: metadata is profile data and must not be
/// used as an authorization source.
enum AppRole {
  customer('customer'),
  venueOwner('venue_owner'),
  instituteOwner('institute_owner'),
  eventOrganizer('event_organizer'),
  supportAgent('support_agent'),
  administrator('administrator'),
  superAdministrator('super_administrator');

  const AppRole(this.databaseValue);

  final String databaseValue;

  static AppRole? fromDatabase(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final role in AppRole.values) {
      if (role.databaseValue == normalized) return role;
    }
    return null;
  }
}

extension AppRoleSet on Set<AppRole> {
  bool get canManageVenues => contains(AppRole.venueOwner);

  bool get canViewAdminTools =>
      contains(AppRole.administrator) || contains(AppRole.superAdministrator);
}
