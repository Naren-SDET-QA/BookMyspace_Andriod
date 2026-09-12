import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_audit_screen.dart';
import '../../features/admin/presentation/screens/admin_cms_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_directory_screens.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/domain/app_role.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/widgets/role_gate.dart';
import '../config/app_config.dart';
import 'search_route.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/booking/domain/booking.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/booking_success_screen.dart';
import '../../features/booking/presentation/screens/my_bookings_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/courses_list_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_registration_screen.dart';
import '../../features/owner/presentation/screens/owner_categories_screen.dart';
import '../../features/owner/presentation/screens/owner_bookings_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_venues_screen.dart';
import '../../features/owner_venues/presentation/screens/create_venue_screen.dart';
import '../../features/legal/presentation/screens/privacy_policy_screen.dart';
import '../../features/legal/presentation/screens/terms_of_service_screen.dart';
import '../../features/payments/presentation/screens/payment_screen.dart';
import '../../features/qr_checkin/presentation/screens/qr_check_in_scanner_screen.dart';
import '../../features/saved/presentation/screens/saved_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/features_hub_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/map/presentation/screens/venue_map_screen.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/venues/domain/venue.dart';
import '../../features/venues/presentation/screens/venue_details_screen.dart';
import '../localization/app_localizations.dart';

/// Route names used for navigation.
abstract class AppRoutes {
  static const root = '/';
  static const onboarding = '/onboarding';
  static const shell = '/home';
  static const home = '/home';
  static const search = '/search';
  static const map = '/map';
  static const bookings = '/bookings';
  static const saved = '/saved';
  static const profile = '/profile';
  static const settings = '/settings';
  static const login = '/login';
  static const venueDetails = '/venues/:id';
  static const bookingFlow = '/venues/:id/book';
  static const paymentFlow = '/bookings/:id/pay';
  static const bookingSuccess = '/bookings/:id/success';
  static const eventsList = '/events';
  static const eventDetails = '/events/:id';
  static const coursesList = '/courses';
  static const courseDetails = '/courses/:id';
  static const notifications = '/notifications';
  static const analytics = '/analytics';
  static const support = '/support';
  static const adminDashboard = '/admin';
  static const adminUsers = '/admin/users';
  static const adminOwners = '/admin/owners';
  static const adminVenues = '/admin/venues';
  static const adminBookings = '/admin/bookings';
  static const adminPayments = '/admin/payments';
  static const adminEvents = '/admin/events';
  static const adminCourses = '/admin/courses';
  static const adminSupport = '/admin/support';
  static const adminAudit = '/admin/audit';
  static const adminCms = '/admin/cms';
  static const ownerRegistration = '/owner/register';
  static const ownerDashboard = '/owner';
  static const ownerCategories = '/owner/categories';
  static const ownerVenues = '/owner/venues';
  static const ownerVenueCreate = '/owner/venues/create';
  static const ownerBookings = '/owner/bookings';
  static const privacyPolicy = '/privacy';
  static const termsOfService = '/terms';
  static const qrScanner = '/qr-scanner';
  static const featuresHub = '/features';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

/// Default initial location for the live app router.
final routerInitialLocationProvider =
    Provider<String>((ref) => AppRoutes.shell);

/// Stable application router. Auth changes refresh redirects without
/// constructing a new [GoRouter] on every widget rebuild.
final appRouterProvider = Provider.family<GoRouter, String>((
  ref,
  initialLocation,
) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authNotifierProvider, (previous, next) {
    final previousUserId = previous?.user?.id;
    final nextUserId = next.user?.id;
    if (previous.runtimeType == next.runtimeType &&
        previousUserId == nextUserId) {
      return;
    }
    refresh.value++;
  });

  final router = createAppRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
    authStateReader: () => ref.read(authNotifierProvider),
    allowUnauthenticatedPreview: AppConfig.isUiTestMode,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Creates the application router. [initialLocation] is overridable in tests.
///
/// When [authStateReader] is provided, redirects read live auth state on every
/// refresh. Otherwise [currentUser] / [authReady] are used (tests).
///
/// A `null` user disables gating when [allowUnauthenticatedPreview] is
/// enabled. Preview mode does not create an authentication session.
GoRouter createAppRouter({
  String initialLocation = AppRoutes.shell,
  AuthUser? currentUser,
  bool authReady = true,
  bool allowUnauthenticatedPreview = false,
  Listenable? refreshListenable,
  AuthState Function()? authStateReader,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      var ready = authReady;
      var user = currentUser;
      if (authStateReader != null) {
        final auth = authStateReader();
        ready = auth is! AuthLoading;
        user = auth.user;
      }
      final path = state.uri.path.isEmpty ? AppRoutes.root : state.uri.path;
      // Never leave `/` unmatched. Auth still loading used to return null here,
      // which made go_router throw: no routes for location: /
      if (path == AppRoutes.root || state.matchedLocation == AppRoutes.root) {
        if (!ready || allowUnauthenticatedPreview) return AppRoutes.shell;
        return user == null ? AppRoutes.login : AppRoutes.shell;
      }
      if (!ready) return null;
      final isPublic =
          path == AppRoutes.onboarding || path == AppRoutes.login;
      if (allowUnauthenticatedPreview) return null;
      if (user == null) {
        return isPublic ? null : AppRoutes.login;
      }
      return isPublic ? AppRoutes.shell : null;
    },
    errorBuilder: (context, state) {
      return _UnknownRouteScreen(location: state.uri.path);
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) => const HomeScreen(),
        redirect: (context, state) => AppRoutes.shell,
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const NotificationsScreen(),
        redirect: (context, state) => AppRoutes.notifications,
      ),
      GoRoute(
        path: '/venue/:id',
        redirect: (context, state) =>
            '/venues/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/course/:id',
        redirect: (context, state) =>
            '/courses/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/event/:id',
        redirect: (context, state) =>
            '/events/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.map,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final params = SearchRouteParams.fromGoRouterState(state);
          return VenueMapScreen(
            initialVenueId: params.venueId,
            initialCategory: params.categorySlug,
            initialQuery: params.query,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.venueDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            VenueDetailsScreen(venueId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.bookingFlow,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final venue = extra is Venue ? extra : null;
          if (venue == null) {
            // Bookmark/refresh navigation without a venue object — fall back
            // to the details screen which can re-fetch the venue.
            return VenueDetailsScreen(
              venueId: state.pathParameters['id'] ?? '',
            );
          }
          return BookingScreen(venue: venue);
        },
      ),
      GoRoute(
        path: AppRoutes.eventsList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EventsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.eventDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            EventDetailScreen(eventId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.courseDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CourseDetailScreen(
          courseId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.analytics,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {
            AppRole.venueOwner,
            AppRole.administrator,
            AppRole.superAdministrator,
          },
          child: AnalyticsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.support,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SupportTicketsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminUsersScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminOwners,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminOwnersScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminVenues,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminVenuesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminBookings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminBookingsBlockedScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminPayments,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminPaymentsBlockedScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminEvents,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminEventsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminCourses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminCoursesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminSupport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {
            AppRole.administrator,
            AppRole.superAdministrator,
            AppRole.supportAgent,
          },
          child: AdminSupportScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminAudit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminAuditScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminCms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminCmsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerRegistration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {
            AppRole.venueOwner,
            AppRole.instituteOwner,
            AppRole.eventOrganizer,
          },
          child: OwnerDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerCategories,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.venueOwner},
          child: OwnerCategoriesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerVenues,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.venueOwner},
          child: OwnerVenuesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerBookings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.venueOwner},
          child: OwnerBookingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerVenueCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extraVenue = state.extra as Venue?;
          return RoleGate(
            requiredRoles: const {AppRole.venueOwner},
            child: CreateVenueScreen(existingVenue: extraVenue),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentFlow,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final booking = extra is Booking ? extra : null;
          if (booking == null) {
            // Deep link without a booking object — show the bookings tab.
            return const MyBookingsScreen();
          }
          return PaymentScreen(booking: booking);
        },
      ),
      GoRoute(
        path: AppRoutes.bookingSuccess,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => BookingSuccessScreen(
          bookingId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.qrScanner,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const QrCheckInScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.featuresHub,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FeaturesHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.saved,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SavedScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) {
                  final params = SearchRouteParams.fromGoRouterState(state);
                  return SearchScreen(
                    initialCategory: params.categorySlug,
                    initialQuery: params.query,
                    routeQuery: params.toQuery(),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                builder: (context, state) => const MyBookingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.coursesList,
                builder: (context, state) => const CoursesListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          10,
          0,
          10,
          bottomInset > 0 ? bottomInset : 10,
        ),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xF0102433)
                  : Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A)
                      .withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: NavigationBar(
                // Keep labels visible so first-time users can understand each
                // destination without relying on platform-specific icon knowledge.
                // Material 3 sizes the six destinations responsively on phones and
                // preserves their accessibility labels on every platform.
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home_rounded),
                    label: l10n.navHome,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.notifications_outlined),
                    selectedIcon: const Icon(Icons.notifications_rounded),
                    label: isCompact ? 'Alerts' : l10n.notifications,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.search_outlined),
                    selectedIcon: const Icon(Icons.search_rounded),
                    label: l10n.navSearch,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.receipt_long_outlined),
                    selectedIcon: const Icon(Icons.receipt_long_rounded),
                    label: l10n.navBookings,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.school_outlined),
                    selectedIcon: const Icon(Icons.school_rounded),
                    label: l10n.courses,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline_rounded),
                    selectedIcon: const Icon(Icons.person_rounded),
                    label: l10n.navProfile,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  'This page is not available.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  location,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Temporary placeholder replaced with a real screen in a later milestone.
class ProfilePlaceholderScreen extends StatelessWidget {
  const ProfilePlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Profile (M7)')));
  }
}
