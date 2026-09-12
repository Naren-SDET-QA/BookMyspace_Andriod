/// Modular feature catalog. Enablement is configuration, never authorization.
///
/// Admin privileges cannot be granted by flipping [enabled]. Backend RLS and
/// `user_roles` remain the source of truth. [requiredRoles] is documentation
/// for humans and tests; [RoleGate] still reads `user_roles`.
class FeatureRoute {
  const FeatureRoute({required this.path, this.name = ''});

  final String path;
  final String name;
}

class FeatureCapability {
  const FeatureCapability({required this.id, required this.description});

  final String id;
  final String description;
}

class FeatureModule {
  const FeatureModule({
    required this.id,
    required this.name,
    required this.enabled,
    this.routes = const [],
    this.capabilities = const [],
    this.requiredRoles = const [],
  });

  final String id;
  final String name;
  final bool enabled;
  final List<String> routes;
  final List<FeatureCapability> capabilities;
  final List<String> requiredRoles;
}

class FeatureRegistry {
  const FeatureRegistry(this.modules);

  final List<FeatureModule> modules;

  FeatureModule? byId(String id) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  bool isEnabled(String id) => byId(id)?.enabled ?? false;

  static const FeatureRegistry product = FeatureRegistry([
    FeatureModule(id: 'home', name: 'Home', enabled: true, routes: ['/home']),
    FeatureModule(
        id: 'search', name: 'Search', enabled: true, routes: ['/search']),
    FeatureModule(
        id: 'bookings', name: 'Bookings', enabled: true, routes: ['/bookings']),
    FeatureModule(
        id: 'payments', name: 'Payments', enabled: true, routes: ['/bookings/:id/pay']),
    FeatureModule(
        id: 'courses', name: 'Courses', enabled: true, routes: ['/courses']),
    FeatureModule(
        id: 'events', name: 'Events', enabled: true, routes: ['/events']),
    FeatureModule(
        id: 'owner', name: 'Owner', enabled: true, routes: ['/owner']),
    FeatureModule(
        id: 'admin', name: 'Admin', enabled: true, routes: ['/admin']),
    FeatureModule(
        id: 'support', name: 'Support', enabled: true, routes: ['/support']),
    FeatureModule(
        id: 'analytics', name: 'Analytics', enabled: true, routes: ['/analytics']),
    FeatureModule(
        id: 'reviews', name: 'Reviews', enabled: true),
    FeatureModule(
        id: 'favorites', name: 'Favorites', enabled: true, routes: ['/saved']),
    FeatureModule(
        id: 'location', name: 'Location', enabled: true),
    FeatureModule(
      id: 'referrals',
      name: 'Referrals',
      enabled: false,
      requiredRoles: const ['customer'],
    ),
  ]);
}
