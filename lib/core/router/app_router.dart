import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState, AuthUser;

import '../../features/accommodations/domain/accommodation.dart';
import '../../features/accommodations/presentation/screens/accommodation_detail_screen.dart';
import '../../features/accommodations/presentation/screens/accommodation_list_screen.dart';
import '../../features/accommodations/presentation/screens/stay_management_screens.dart';
import '../../features/admin/presentation/screens/admin_app_sections_screen.dart';
import '../../features/admin/presentation/screens/admin_audit_screen.dart';
import '../../features/admin/presentation/screens/admin_cms_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/cms/presentation/screens/admin_media_library_screen.dart';
import '../../features/admin/presentation/screens/admin_directory_screens.dart';
import '../../features/admin_payment/presentation/screens/admin_payment_health_screen.dart';
import '../../features/admin_payment/presentation/screens/admin_transaction_ledger_screen.dart';
import '../../features/integrations/presentation/screens/admin_integrations_screen.dart';
import '../../features/modules/presentation/screens/admin_modules_screen.dart';
import '../../features/home/presentation/screens/admin_home_appearance_screen.dart';
import '../../features/theme/presentation/screens/admin_theme_customizer_screen.dart';
import '../../features/admin/presentation/screens/admin_categories_screen.dart';
import '../../features/admin/presentation/screens/admin_content_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_feature_configuration_screen.dart';
import '../../features/admin/presentation/screens/admin_health_screen.dart';
import '../../features/admin/presentation/screens/admin_help_center_screen.dart';
import '../../features/admin/presentation/screens/admin_listing_fields_screen.dart';
import '../../features/admin/presentation/screens/admin_listings_screen.dart';
import '../../features/admin/presentation/screens/admin_observability_providers_screen.dart';
import '../../features/admin/presentation/screens/admin_observability_screen.dart';
import '../../features/admin/presentation/screens/admin_oversight_screen.dart';
import '../../features/admin/presentation/screens/admin_promotions_screen.dart';
import '../../features/admin/presentation/screens/admin_settings_screen.dart';
import '../../features/admin/presentation/screens/admin_tenant_configuration_screen.dart';
import '../../features/admin/presentation/screens/admin_venue_claims_screen.dart';
import '../../features/admin/presentation/screens/admin_venue_discovery_review_screen.dart';
import '../../features/ai/presentation/screens/assistant_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/domain/app_role.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/widgets/role_gate.dart';
import '../config/app_config.dart';
import 'search_route.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/booking/domain/booking.dart';
import '../../features/booking/presentation/booking_providers.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/booking_success_screen.dart';
import '../../features/booking/presentation/screens/invoice_screen.dart';
import '../../features/booking/presentation/screens/my_bookings_screen.dart';
import '../../features/business/presentation/screens/business_plan_configuration_screen.dart';
import '../../features/business/presentation/screens/business_pricing_configuration_screen.dart';
import '../../features/checkin/presentation/screens/qr_check_in_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/courses_list_screen.dart';
import '../../features/courses/presentation/screens/admin_education_screen.dart';
import '../../features/courses/presentation/screens/education_hub_screen.dart';
import '../../features/courses/presentation/screens/institute_detail_screen.dart'
    as edu;
import '../../features/courses/presentation/screens/my_courses_screen.dart';
import '../../features/courses/presentation/screens/owner_course_editor_screen.dart';
import '../../features/courses/presentation/screens/owner_courses_screen.dart';
import '../../features/courses/presentation/screens/owner_institute_dashboard_screen.dart';
import '../../features/courses/domain/course.dart';
import '../../features/customer_analytics/presentation/screens/customer_analytics_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/home/presentation/screens/customer_category_preferences_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/institutes/presentation/screens/institute_detail_screen.dart';
import '../../features/institutes/presentation/screens/institute_owner_dashboard_screen.dart';
import '../../features/institutes/presentation/screens/institutes_list_screen.dart';
import '../../features/invoices/presentation/screens/invoice_screens.dart'
    as invoice_feature;
import '../../features/legal/presentation/screens/privacy_policy_screen.dart';
import '../../features/legal/presentation/screens/terms_of_service_screen.dart';
import '../../features/location/presentation/screens/location_management_screen.dart';
import '../../features/meeting_rooms/presentation/screens/meeting_room_booking_screen.dart';
import '../../features/meeting_rooms/presentation/screens/meeting_room_detail_screen.dart';
import '../../features/meeting_rooms/presentation/screens/meeting_room_owner_screen.dart';
import '../../features/meeting_rooms/presentation/screens/meeting_rooms_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_operations_screen.dart';
import '../../features/owner/presentation/screens/owner_profile_screen.dart';
import '../../features/owner/presentation/screens/owner_registration_screen.dart';
import '../../features/owner/presentation/screens/owner_categories_screen.dart';
import '../../features/owner/presentation/screens/owner_bookings_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_venues_screen.dart';
import '../../features/owner/presentation/screens/registration_field_configuration_screen.dart';
import '../../features/owner/presentation/screens/venue_optimizer_screen.dart';
import '../../features/owner_bookings/presentation/screens/create_offline_booking_screen.dart';
import '../../features/owner_bookings/presentation/screens/owner_bookings_screen.dart'
    as owner_bookings_v1;
import '../../features/owner_bookings/presentation/screens/owner_calendar_screen.dart';
import '../../features/owner_venues/presentation/screens/create_venue_screen.dart';
import '../../features/owner_venues/presentation/screens/media_manager_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_availability_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_venues_screen.dart';
import '../../features/payments/presentation/screens/booking_success_screen.dart'
    as payment_success;
import '../../features/payments/presentation/screens/commerce_payment_screen.dart';
import '../../features/payments/presentation/screens/payment_health_screen.dart';
import '../../features/payments/presentation/screens/payment_history_screen.dart';
import '../../features/payments/presentation/screens/payment_screen.dart';
import '../../features/qr_checkin/presentation/screens/qr_check_in_scanner_screen.dart';
import '../../features/receipts/presentation/screens/receipt_screen.dart';
import '../../features/payments/presentation/screens/receipt_screen.dart'
    as payment_receipt;
import '../../features/registration/presentation/module_configuration_screen.dart';
import '../../features/registration/presentation/module_registration_screen.dart';
import '../../features/registration/presentation/module_submission_status_screen.dart';
import '../../features/registration/presentation/screens/registration_screens.dart';
import '../../features/registration/presentation/unified_registration_screen.dart';
import '../../features/rewards/presentation/screens/admin_reward_config_screen.dart';
import '../../features/rewards/presentation/screens/referral_screen.dart';
import '../../features/rewards/presentation/screens/wallet_screen.dart';
import '../../features/saved/presentation/screens/saved_screen.dart';
import '../../features/search/domain/ai_search_intent.dart';
import '../../features/search/presentation/screens/map_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/features_hub_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/map/presentation/screens/venue_map_screen.dart';
import '../../features/settings/presentation/screens/theme_customizer_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/sports/presentation/screens/sports_screens.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/venue_discovery/infrastructure/supabase_discovery_repository.dart';
import '../../features/venue_discovery/presentation/screens/venue_discovery_screen.dart';
import '../../features/venues/domain/venue.dart';
import '../../features/venues/presentation/screens/venue_details_screen.dart';
import '../../features/navigation/presentation/nav_tab_labels.dart';
import '../../features/navigation/domain/nav_tabs.dart';
import '../../features/navigation/presentation/nav_tabs_providers.dart';
import '../../features/navigation/presentation/screens/admin_nav_tabs_screen.dart';
import '../../features/cms/presentation/screens/admin_catalog_screen.dart';
import '../../features/navigation/presentation/screens/assistant_tab_screen.dart';
import '../config/settings_controller.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen_v1.dart';
import '../../features/auth/presentation/screens/login_screen_v1.dart';
import '../../features/auth/presentation/screens/profile_screen_v1.dart';
import '../../features/booking/presentation/screens/booking_screen_v1.dart';
import '../../features/booking/presentation/screens/my_bookings_screen_v1.dart';
import '../../features/courses/presentation/screens/courses_list_screen_v1.dart';
import '../../features/home/presentation/screens/home_screen_v1.dart';
import '../../features/notifications/presentation/screens/notifications_screen_v1.dart';
import '../../features/owner/presentation/screens/owner_registration_screen_v1.dart';
import '../../features/owner_venues/presentation/screens/create_venue_screen_v1.dart';
import '../../features/owner_venues/presentation/screens/owner_venues_screen_v1.dart';
import '../../features/payments/presentation/screens/payment_screen_v1.dart';
import '../../features/search/presentation/screens/search_screen_v1.dart';
import '../../features/settings/presentation/screens/settings_screen_v1.dart';
import '../../features/venues/presentation/screens/venue_details_screen_v1.dart';
import '../localization/app_localizations.dart';
import '../modular/feature_id.dart';
import '../modular/feature_providers.dart';
import '../modular/feature_registry.dart';
import '../modular/shell_destinations.dart';
import '../theme/app_theme.dart';
import '../../features/admin/presentation/admin_settings_providers.dart';
import '../widgets/test_id.dart';

/// Route names used for navigation.
abstract class AppRoutes {
  static const root = '/';
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const shell = '/home';
  static const home = '/home';
  static const search = '/search';
  static const map = '/map';
  static const bookings = '/bookings';
  static const saved = '/saved';
  static const profile = '/profile';
  static const settings = '/settings';
  static const categoryPreferences = '/settings/categories';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const venueDetails = '/venues/:id';
  static const bookingFlow = '/venues/:id/book';
  static const paymentFlow = '/bookings/:id/pay';
  static const bookingSuccess = '/bookings/:id/success';
  static const receipt = '/bookings/:id/receipt';
  static const commercePayment = '/commerce/:id/pay';
  static const bookingResult = '/bookings/:id/status';
  /// Payment-side receipt (release/v1.0). The itemized GST receipt owns
  /// [receipt]; this one moved so both stay reachable.
  static const bookingReceipt = '/bookings/:id/payment-receipt';
  static const eventsList = '/events';
  static const eventDetails = '/events/:id';
  static const coursesList = '/courses';
  static const courseDetails = '/courses/:id';
  static const education = '/education';
  static const instituteDetails = '/institutes/:id';
  static const myCourses = '/my-courses';
  static const pgList = '/pg';
  static const pgDetails = '/pg/:id';
  static const staysList = '/stays';
  static const stayDetails = '/stays/:id';
  static const myStays = '/stays/bookings/mine';
  static const notifications = '/notifications';
  static const analytics = '/analytics';
  static const support = '/support';
  static const adminDashboard = '/admin';
  static const adminUsers = '/admin/users';
  static const adminOwners = '/admin/owners';
  static const adminVenues = '/admin/venues';
  static const adminCategories = '/admin/categories';
  static const adminBookings = '/admin/bookings';
  static const adminPayments = '/admin/payments';
  static const adminPaymentsLedger = '/admin/payments/ledger';
  static const adminEvents = '/admin/events';
  static const adminCourses = '/admin/courses';
  static const adminEducation = '/admin/education';
  static const adminSupport = '/admin/support';
  static const adminAudit = '/admin/audit';
  static const adminCms = '/admin/cms';
  static const adminIntegrations = '/admin/integrations';
  static const adminModules = '/admin/modules';
  static const adminHomeLayout = '/admin/home-layout';
  static const adminTheme = '/admin/theme';
  static const adminListings = '/admin/listings';
  static const adminVenueDiscoveryReview = '/admin/venue-discovery-review';
  static const adminAppSections = '/admin/app-sections';
  static const adminFeatureConfiguration = '/admin/features';
  static const adminTenantConfiguration = '/admin/tenant-configuration';
  static const adminRefunds = '/admin/refunds';
  static const adminPaymentHealth = '/admin/payment-health';
  static const adminObservability = '/admin/observability';
  static const adminHealth = '/admin/health';
  static const adminSettings = '/admin/settings';
  static const adminObservabilityProviders = '/admin/observability/providers';
  static const adminHelp = '/admin/help';
  static const adminPromotions = '/admin/promotions';
  static const adminListingFields = '/admin/listing-fields';
  static const adminVenueImport = '/admin/venue-import';
  static const adminVenueClaims = '/admin/venue-claims';
  static const adminContent = '/admin/content';
  static const unifiedRegistration = '/register';
  static const adminLocations = '/admin/locations';
  /// Full-screen AI assistant (release/v1.0). [assistantTab] is the shell tab.
  static const assistant = '/ai-assistant';
  static const chat = '/chat';
  static const homeModern = '/home-modern';
  static const checkIn = '/check-in';
  static const institutesList = '/institutes';
  /// Institute *listing* dashboard (release/v1.0). The education dashboard
  /// owns [ownerInstituteDashboard] at `/owner/institute`.
  static const ownerInstitute = '/owner/institute-listing';
  static const themeCustomizer = '/theme';
  static const ownerRegistration = '/owner/register';
  static const ownerDashboard = '/owner';
  static const ownerCategories = '/owner/categories';
  static const ownerVenues = '/owner/venues';
  static const ownerVenueCreate = '/owner/venues/create';
  static const ownerBookings = '/owner/bookings';
  static const ownerCourses = '/owner/courses';
  static const ownerInstituteDashboard = '/owner/institute';
  static const ownerCourseCreate = '/owner/courses/create';
  static const ownerCourseEdit = '/owner/courses/edit';
  static const ownerVenueEdit = '/owner/venues/:id/edit';
  static const ownerVenueMedia = '/owner/venues/:id/media';
  static const ownerVenueAvailability = '/owner/venues/:id/availability';
  static const ownerCalendar = '/owner/calendar';
  static const ownerBookingCreate = '/owner/bookings/create';
  static const ownerLocations = '/owner/locations';
  static const ownerOptimizer = '/owner/optimizer';
  static const ownerStays = '/owner/stays';
  static const ownerMeetingRooms = '/owner/meeting-rooms';
  static const ownerSports = '/owner/sports';
  static const ownerProfile = '/owner/profile';
  static const ownerAvailability = '/owner/availability';
  static const ownerOfflineBooking = '/owner/offline-booking';
  static const ownerPayments = '/owner/payments';
  static const meetingRooms = '/meeting-rooms';
  static const meetingRoomDetails = '/meeting-rooms/:id';
  static const meetingRoomBooking = '/meeting-rooms/:id/book';
  static const sportsVenues = '/sports';
  static const sportsVenueDetails = '/sports/:id';
  static const sportsBooking = '/sports/:id/book';
  static const registrationForms = '/owner/registration-forms';
  static const registrationFill = '/registration/forms/:id/fill';
  static const invoiceConfig = '/owner/invoice-settings';
  static const invoiceView = '/invoices/:id';
  static const adminRegistrationFields = '/admin/registration-fields';
  static const adminBusinessPricing = '/admin/business-pricing';
  static const adminRewards = '/admin/rewards';
  static const adminBusinessPlans = '/admin/business-plans';
  static const bookingInvoice = '/bookings/:id/invoice';
  static const paymentHistory = '/payments';
  static const wallet = '/wallet';
  static const referrals = '/referrals';
  static const customerAnalytics = '/my-analytics';
  static const adminModuleConfiguration = '/admin/module-configuration';
  static const moduleRegistration = '/register/:module';
  static const moduleSubmissionStatus = '/registration/:id';

  static String ownerVenueEditPath(String id) => '/owner/venues/$id/edit';
  static String ownerVenueAvailabilityPath(String id) =>
      '/owner/venues/$id/availability';
  static const privacyPolicy = '/privacy';
  static const termsOfService = '/terms';
  static const qrScanner = '/qr-scanner';
  static const featuresHub = '/features';
  static const assistantTab = '/assistant';
  static const adminNavTabs = '/admin/nav-tabs';
  static const adminCatalog = '/admin/catalog';
  static const adminMedia = '/admin/media';

  // Routes that existed on both lineages with different screens. The main
  // lineage keeps the original path; the release/v1.0 screen moved here.
  static const adminCategoryControls = '/admin/category-controls';
  static const adminPaymentsOversight = '/admin/payments-oversight';
  static const ownerBookingsManager = '/owner/bookings-manager';
  static const educationInstituteDetails = '/education/institutes/:id';
  static const venueMap = '/venue-map';

  // release/v1.0 screens that coexist with the main-lineage screens.
  static const v1Home = '/v1/home';
  static const v1Search = '/v1/search';
  static const v1VenueDetails = '/v1/venues/:id';
  static const v1BookingFlow = '/v1/venues/:id/book';
  static const v1PaymentFlow = '/v1/bookings/:id/pay';
  static const v1Bookings = '/v1/bookings';
  static const v1Profile = '/v1/profile';
  static const v1Settings = '/v1/settings';
  static const v1Login = '/v1/login';
  static const v1Notifications = '/v1/notifications';
  static const v1Courses = '/v1/courses';
  static const v1AdminDashboard = '/v1/admin';
  static const v1OwnerRegistration = '/v1/owner/register';
  static const v1OwnerVenues = '/v1/owner/venues';
  static const v1OwnerVenueCreate = '/v1/owner/venues/create';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

// Explicit navigator keys for each StatefulShellBranch.
// go_router 14.x requires these to be stable, top-level singletons — not
// created inside build — so it can reliably resolve the correct navigator
// when a parentNavigatorKey route (e.g. Settings) pushes above the shell.
final _shellHomeNavKey      = GlobalKey<NavigatorState>(debugLabel: 'shell-home');
final _shellAlertsNavKey    = GlobalKey<NavigatorState>(debugLabel: 'shell-alerts');
final _shellSearchNavKey    = GlobalKey<NavigatorState>(debugLabel: 'shell-search');
final _shellBookingsNavKey  = GlobalKey<NavigatorState>(debugLabel: 'shell-bookings');
final _shellCoursesNavKey   = GlobalKey<NavigatorState>(debugLabel: 'shell-courses');
final _shellProfileNavKey   = GlobalKey<NavigatorState>(debugLabel: 'shell-profile');
final _shellAssistantNavKey = GlobalKey<NavigatorState>(debugLabel: 'shell-assistant');
final _shellMapNavKey       = GlobalKey<NavigatorState>(debugLabel: 'shell-map');
final _shellSavedNavKey     = GlobalKey<NavigatorState>(debugLabel: 'shell-saved');
final _shellChatNavKey      = GlobalKey<NavigatorState>(debugLabel: 'shell-chat');

/// Returns an internal login URL that remembers the protected destination.
///
/// Keeping the destination in the query string means a deep link such as
/// `/bookings` is still the user's destination after authentication. The
/// value is validated again before it is used, so it cannot become an open
/// redirect.
String loginLocationFor(Uri destination) {
  if (destination.path == AppRoutes.login) return AppRoutes.login;
  return Uri(
    path: AppRoutes.login,
    queryParameters: {'redirect': destination.toString()},
  ).toString();
}

/// Returns the safe post-auth destination encoded on the login route.
String authenticatedLocationFromLogin(Uri loginUri) {
  final destination = loginUri.queryParameters['redirect'];
  if (destination == null || destination.isEmpty) return AppRoutes.shell;

  final parsed = Uri.tryParse(destination);
  if (parsed == null ||
      parsed.hasScheme ||
      parsed.hasAuthority ||
      !parsed.path.startsWith('/') ||
      parsed.path.startsWith('//') ||
      parsed.path == AppRoutes.login) {
    return AppRoutes.shell;
  }
  return parsed.toString();
}

/// Default initial location for the live app router.
final routerInitialLocationProvider = Provider<String>(
  (ref) => AppRoutes.shell,
);

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
        previousUserId == nextUserId &&
        previous?.user?.role == next.user?.role) {
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
  bool allowUnauthenticatedTestAccess = false,
  FeatureRegistry? features,
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
      final allowWithoutUser =
          allowUnauthenticatedPreview || allowUnauthenticatedTestAccess;
      // Never leave `/` unmatched. Auth still loading used to return null here,
      // which made go_router throw: no routes for location: /
      if (path == AppRoutes.root || state.matchedLocation == AppRoutes.root) {
        if (!ready || allowWithoutUser) return AppRoutes.shell;
        return user == null ? AppRoutes.login : AppRoutes.shell;
      }
      if (allowUnauthenticatedPreview) return null;
      if (ready && user != null && path == AppRoutes.login) {
        return authenticatedLocationFromLogin(state.uri);
      }
      final resolved = resolveAppRedirect(
        location: path,
        currentUser: user,
        authReady: ready,
        allowUnauthenticatedTestAccess: allowUnauthenticatedTestAccess,
        features: features,
      );
      // Keep the protected destination so the user lands there after login.
      if (resolved == AppRoutes.login && user == null) {
        return loginLocationFor(state.uri);
      }
      return resolved;
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
        redirect: (context, state) => '/venues/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/course/:id',
        redirect: (context, state) => '/courses/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/event/:id',
        redirect: (context, state) => '/events/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/venue-discovery',
        builder: (context, state) => VenueDiscoveryScreen(
          repository: SupabaseDiscoveryRepository(Supabase.instance.client),
        ),
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
        path: AppRoutes.forgotPassword,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.venueMap,
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
        path: AppRoutes.categoryPreferences,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CustomerCategoryPreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.themeCustomizer,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ThemeCustomizerScreen(),
      ),
      GoRoute(
        path: AppRoutes.assistant,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AssistantScreen(),
      ),
      // Extra Home page (modern design) — preview without changing the
      // admin setting. The default Home tab is unchanged.
      GoRoute(
        path: AppRoutes.homeModern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const HomeScreenV1(forceModernLayout: true),
      ),
      GoRoute(
        path: AppRoutes.checkIn,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const QrCheckInScreen(),
      ),
      GoRoute(
        path: AppRoutes.institutesList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InstitutesListScreen(),
      ),
      GoRoute(
        path: AppRoutes.instituteDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => InstituteDetailScreen(
          instituteId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerInstitute,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const InstituteOwnerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminListings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminListingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminVenueDiscoveryReview,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminVenueDiscoveryReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminCategoryControls,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminCategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAppSections,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminAppSectionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminFeatureConfiguration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminFeatureConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminTenantConfiguration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AdminTenantConfigurationScreen(
          organizationId: state.uri.queryParameters['organization_id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.adminObservability,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminObservabilityScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminHealth,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminHealthScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminObservabilityProviders,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminObservabilityProvidersScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminHelp,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminHelpCenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminPromotions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminPromotionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminBookings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AdminOversightScreen(kind: AdminOversightKind.bookings),
      ),
      GoRoute(
        path: AppRoutes.adminPaymentsOversight,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AdminOversightScreen(kind: AdminOversightKind.payments),
      ),
      GoRoute(
        path: AppRoutes.adminRefunds,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AdminOversightScreen(kind: AdminOversightKind.refunds),
      ),
      GoRoute(
        path: AppRoutes.adminPaymentHealth,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PaymentHealthScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminListingFields,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminListingFieldsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminContent,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminContentScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminVenueImport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => VenueDiscoveryScreen(
          repository: SupabaseDiscoveryRepository(Supabase.instance.client),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminVenueClaims,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminVenueClaimsScreen(),
      ),
      GoRoute(
        path: AppRoutes.unifiedRegistration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const UnifiedRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.coursesList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CoursesListScreen(),
      ),
      GoRoute(
        path: AppRoutes.pgList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccommodationListScreen(module: AccommodationModule.pg),
      ),
      GoRoute(
        path: AppRoutes.pgDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AccommodationDetailScreen(
          propertyId: state.pathParameters['id'] ?? '',
          module: AccommodationModule.pg,
        ),
      ),
      GoRoute(
        path: AppRoutes.staysList,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccommodationListScreen(module: AccommodationModule.stay),
      ),
      GoRoute(
        path: AppRoutes.stayDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => AccommodationDetailScreen(
          propertyId: state.pathParameters['id'] ?? '',
          module: AccommodationModule.stay,
        ),
      ),
      GoRoute(
        path: AppRoutes.meetingRooms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MeetingRoomsScreen(),
      ),
      GoRoute(
        path: AppRoutes.meetingRoomDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MeetingRoomDetailScreen(roomId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.meetingRoomBooking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MeetingRoomBookingScreen(roomId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.sportsVenues,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SportsVenuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.sportsVenueDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            SportsVenueDetailScreen(venueId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.sportsBooking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            SportsBookingScreen(venueId: state.pathParameters['id'] ?? ''),
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
        builder: (context, state) =>
            CourseDetailScreen(courseId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.education,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => EducationHubScreen(
          initialQuery: state.uri.queryParameters['q'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.educationInstituteDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => edu.InstituteDetailScreen(
          instituteId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.myCourses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyCoursesScreen(),
      ),
      GoRoute(
        path: AppRoutes.registrationFill,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => RegistrationFillScreen(
          formId: state.pathParameters['id'] ?? '',
          bookingId: state.uri.queryParameters['bookingId'],
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
        path: AppRoutes.adminCategories,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: OwnerCategoriesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminPayments,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminPaymentHealthScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminPaymentsLedger,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminTransactionLedgerScreen(),
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
        path: AppRoutes.adminEducation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminEducationScreen(),
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
        path: AppRoutes.adminIntegrations,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminIntegrationsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminModules,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminModulesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminHomeLayout,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminHomeAppearanceScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminTheme,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminThemeCustomizerScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminNavTabs,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminNavTabsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminCatalog,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminCatalogScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminMedia,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {AppRole.administrator, AppRole.superAdministrator},
          child: AdminMediaLibraryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminLocations,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const LocationManagementScreen(admin: true),
      ),
      GoRoute(
        path: AppRoutes.adminRegistrationFields,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const RegistrationFieldConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminBusinessPricing,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BusinessPricingConfigurationScreen(),
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
        path: AppRoutes.ownerInstituteDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {
            AppRole.instituteOwner,
            AppRole.administrator,
            AppRole.superAdministrator,
          },
          child: OwnerInstituteDashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerCourses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {
            AppRole.instituteOwner,
            AppRole.administrator,
            AppRole.superAdministrator,
          },
          child: OwnerCoursesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerCourseCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RoleGate(
          requiredRoles: {
            AppRole.instituteOwner,
            AppRole.administrator,
            AppRole.superAdministrator,
          },
          child: OwnerCourseEditorScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerCourseEdit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extraCourse = state.extra as Course?;
          return RoleGate(
            requiredRoles: const {
              AppRole.instituteOwner,
              AppRole.administrator,
              AppRole.superAdministrator,
            },
            child: OwnerCourseEditorScreen(existing: extraCourse),
          );
        },
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
        path: AppRoutes.ownerVenueEdit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            CreateVenueScreenV1(venueId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.ownerVenueMedia,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MediaManagerScreen(venueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.ownerVenueAvailability,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            OwnerAvailabilityScreen(venueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.ownerBookingsManager,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const owner_bookings_v1.OwnerBookingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerCalendar,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerBookingCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateOfflineBookingScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerLocations,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const LocationManagementScreen(admin: false),
      ),
      GoRoute(
        path: AppRoutes.ownerOptimizer,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const VenueOptimizerScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerAvailability,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const OwnerOperationsScreen(operation: OwnerOperation.availability),
      ),
      GoRoute(
        path: AppRoutes.ownerOfflineBooking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerOperationsScreen(
          operation: OwnerOperation.offlineBooking,
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerPayments,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const OwnerOperationsScreen(operation: OwnerOperation.payments),
      ),
      GoRoute(
        path: AppRoutes.ownerStays,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const StayOwnerScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerMeetingRooms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MeetingRoomOwnerScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerSports,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SportsOwnerScreen(),
      ),
      GoRoute(
        path: AppRoutes.registrationForms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RegistrationFormsAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.invoiceConfig,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const invoice_feature.InvoiceConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.invoiceView,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => invoice_feature.InvoiceScreen(
          invoiceId: state.pathParameters['id'] ?? '',
        ),
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
        path: AppRoutes.bookingInvoice,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          return InvoiceScreen(
            bookingId: state.pathParameters['id'] ?? '',
            initial: extra is Booking ? extra : null,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.bookingResult,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => state.extra is Booking
            ? payment_success.BookingSuccessScreen(
                booking: state.extra! as Booking,
              )
            : const MyBookingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookingReceipt,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => payment_receipt.ReceiptScreen(
          bookingId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.commercePayment,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => CommercePaymentScreen(
          referenceId: state.pathParameters['id'] ?? '',
          amount:
              double.tryParse(state.uri.queryParameters['amount'] ?? '') ?? 0,
          currency: state.uri.queryParameters['currency'] ?? 'INR',
        ),
      ),
      GoRoute(
        path: AppRoutes.myStays,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyStayBookingsScreen(),
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
        builder: (context, state) =>
            BookingSuccessScreen(bookingId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.receipt,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ReceiptScreen(bookingId: state.pathParameters['id'] ?? ''),
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
        path: AppRoutes.paymentHistory,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminRewards,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminRewardConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminModuleConfiguration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ModuleConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.moduleRegistration,
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            state.pathParameters['module'] == 'venue_owner'
            ? AppRoutes.ownerRegistration
            : null,
        builder: (context, state) => ModuleRegistrationScreen(
          moduleKey: state.pathParameters['module'] ?? '',
          venueId: state.uri.queryParameters['venue_id'],
          bookingId: state.uri.queryParameters['booking_id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.moduleSubmissionStatus,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ModuleSubmissionStatusScreen(
          submissionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.adminBusinessPlans,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BusinessPlanConfigurationScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.referrals,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerAnalytics,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CustomerAnalyticsScreen(),
      ),
      // ---------------------------------------------------------------
      // release/v1.0 screens kept alongside the main-lineage versions.
      // ---------------------------------------------------------------
      GoRoute(
        path: AppRoutes.v1Home,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HomeScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1Search,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => SearchScreenV1(
          initialCategory: state.uri.queryParameters['category'],
          initialQuery: state.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: AppRoutes.v1VenueDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            VenueDetailsScreenV1(venueId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.v1BookingFlow,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Venue) return BookingScreenV1(venue: extra);
          return VenueDetailsScreenV1(
            venueId: state.pathParameters['id'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.v1PaymentFlow,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Booking) return PaymentScreenV1(booking: extra);
          return const MyBookingsScreenV1();
        },
      ),
      GoRoute(
        path: AppRoutes.v1Bookings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyBookingsScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1Profile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ProfileScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1Settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1Login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1Notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1Courses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CoursesListScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1AdminDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminDashboardScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1OwnerRegistration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerRegistrationScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1OwnerVenues,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerVenuesScreenV1(),
      ),
      GoRoute(
        path: AppRoutes.v1OwnerVenueCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateVenueScreenV1(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppShell(navigationShell: navigationShell);
        },
        // Branch indices are part of the saved bottom-bar configuration
        // (NavTab.branch and ShellDestination.branchIndex). Never reorder;
        // only append. 0-6 come from the main lineage, 7-9 from release/v1.0.
        branches: [
          // 0
          StatefulShellBranch(
            navigatorKey: _shellHomeNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // 1
          StatefulShellBranch(
            navigatorKey: _shellAlertsNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.notifications,
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          // 2
          StatefulShellBranch(
            navigatorKey: _shellSearchNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) {
                  final params = SearchRouteParams.fromGoRouterState(state);
                  final extra = state.extra;
                  final extraMap =
                      extra is Map<String, dynamic> ? extra : null;
                  final category = extraMap?['category'] as String?;
                  final section = extraMap?['section'] as String?;
                  final query = extraMap?['query'] as String?;
                  final intent = extraMap?['intent'] as AiSearchIntent?;
                  // The release/v1.0 search (section filters, AI intents) is
                  // used when a caller passes those; otherwise the main one.
                  if (section != null || intent != null) {
                    return SearchScreenV1(
                      initialCategory: category ?? params.categorySlug,
                      initialSection: section,
                      initialQuery: query ?? params.query,
                      initialIntent: intent,
                    );
                  }
                  return SearchScreen(
                    initialCategory: category ?? params.categorySlug,
                    initialQuery: query ?? params.query,
                    routeQuery: params.toQuery(),
                  );
                },
              ),
            ],
          ),
          // 3
          StatefulShellBranch(
            navigatorKey: _shellBookingsNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                builder: (context, state) => const MyBookingsScreen(),
              ),
            ],
          ),
          // 4
          StatefulShellBranch(
            navigatorKey: _shellCoursesNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.coursesList,
                builder: (context, state) => const CoursesListScreen(),
              ),
            ],
          ),
          // 5
          StatefulShellBranch(
            navigatorKey: _shellProfileNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          // 6. The assistant is a destination an admin opts into.
          StatefulShellBranch(
            navigatorKey: _shellAssistantNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.assistantTab,
                builder: (context, state) => const AssistantTabScreen(),
              ),
            ],
          ),
          // 7. Map (release/v1.0 primary destination).
          StatefulShellBranch(
            navigatorKey: _shellMapNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const SearchMapScreen(),
              ),
            ],
          ),
          // 8. Saved (release/v1.0 primary destination).
          StatefulShellBranch(
            navigatorKey: _shellSavedNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          // 9. Chat tab (release/v1.0 modern bottom-nav style).
          StatefulShellBranch(
            navigatorKey: _shellChatNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (context, state) => const AssistantScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Pure route authorization used by the router and by role-gating tests.
String? resolveAppRedirect({
  required String location,
  required AuthUser? currentUser,
  required bool authReady,
  bool allowUnauthenticatedTestAccess = false,
  FeatureRegistry? features,
}) {
  // Backend-unavailable Phase-1 paths fail closed even while auth is still
  // resolving, so their repositories cannot issue unsupported requests.
  if (_isPhaseOneBackendUnavailable(location)) return AppRoutes.home;
  if (!authReady) return null;
  final isPublic =
      location == AppRoutes.splash ||
      location == AppRoutes.onboarding ||
      location == AppRoutes.login ||
      location == AppRoutes.forgotPassword ||
      location == AppRoutes.resetPassword ||
      location == AppRoutes.unifiedRegistration ||
      location == AppRoutes.ownerRegistration ||
      location.startsWith('/register/');
  if (currentUser == null && !allowUnauthenticatedTestAccess) {
    if (!isPublic) return AppRoutes.login;
  }
  if (currentUser != null) {
    // Main-lineage routes are guarded by RoleGate with the fine-grained
    // database roles (administrator, support agent, institute owner, ...);
    // the coarse role check below applies to the release/v1.0 routes only.
    final gatedByWidget = _roleGateRoutes.contains(location);
    final isAdminRoute = !gatedByWidget &&
        (location == AppRoutes.adminDashboard ||
            location.startsWith('/admin/'));
    final isOwnerRoute = !gatedByWidget &&
        (location.startsWith('/owner') || location == AppRoutes.analytics);
    if (isAdminRoute && !currentUser.isAdmin) return AppRoutes.profile;
    if (isOwnerRoute && !currentUser.isOwner) return AppRoutes.profile;
    if (location == AppRoutes.resetPassword) return null;
    if (location == AppRoutes.onboarding ||
        location == AppRoutes.login ||
        location == AppRoutes.forgotPassword) {
      return AppRoutes.shell;
    }
  }
  return _featureRedirect(location, features);
}

/// Routes whose screens are wrapped in [RoleGate] (main lineage).
const _roleGateRoutes = {
  '/analytics', '/admin', '/admin/users', '/admin/owners', '/admin/venues',
  '/admin/categories', '/admin/payments', '/admin/payments/ledger',
  '/admin/events', '/admin/courses', '/admin/education', '/admin/support',
  '/admin/audit', '/admin/cms', '/admin/integrations', '/admin/modules',
  '/admin/home-layout', '/admin/theme', '/admin/nav-tabs', '/admin/catalog',
  '/admin/media', '/owner', '/owner/categories', '/owner/venues',
  '/owner/bookings', '/owner/institute', '/owner/courses',
  '/owner/courses/create', '/owner/courses/edit', '/owner/venues/create',
};

/// These Phase-1 flows require schemas/RPCs that are present only on the
/// Phase branch. Keep them out of PROD until their backend contracts have
/// been reviewed and deployed; existing booking and module-registration
/// routes intentionally remain available.
bool _isPhaseOneBackendUnavailable(String location) {
  const unavailableRoots = [
    '/pg',
    '/stays',
    '/owner/stays',
    '/meeting-rooms',
    '/owner/meeting-rooms',
    '/sports',
    '/owner/sports',
    '/commerce',
    '/invoices',
    '/owner/invoice-settings',
    '/owner/registration-forms',
    '/registration/forms',
  ];
  return unavailableRoots.any(
    (root) => location == root || location.startsWith('$root/'),
  );
}

String? _featureRedirect(String location, FeatureRegistry? features) {
  final registry = features ?? FeatureRegistry.instance;
  final feature = FeatureRegistry.featureForRoute(location);
  if (feature != null && !registry.isExposed(feature)) {
    return AppRoutes.home;
  }
  if (location.endsWith('/pay') && !registry.isExposed(FeatureId.razorpay)) {
    return AppRoutes.home;
  }
  return null;
}

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Icon for one bar destination. The bookings tab shows a real badge with
  /// the count of bookings awaiting the user's action; other tabs are plain.
  Widget _navTabIcon(
    NavTabConfig entry, {
    required int actionableBookings,
    required bool selected,
  }) {
    final icon = selected ? entry.tab.selectedIcon : entry.tab.icon;
    if (entry.tab == NavTab.bookings && actionableBookings > 0) {
      return Badge(label: Text('$actionableBookings'), child: Icon(icon));
    }
    return Icon(icon);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Admin settings -> Home UI -> `bottom_nav_style`. `modern` keeps the
    // release/v1.0 5-tab bar; anything else uses the admin-configurable bar
    // (Admin -> Bottom navigation), whose catalog also offers Map/Saved/Chat.
    final navStyle = ShellNavStyle.fromSetting(
      ref.watch(adminSettingsProvider).valueOrNull?.home['bottom_nav_style'],
    );
    if (navStyle == ShellNavStyle.modern) {
      return _buildModernShell(context, ref);
    }
    return _buildConfigurableShell(context, ref);
  }

  Widget _buildConfigurableShell(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    // Real count of bookings needing the user's attention (pending /
    // awaiting owner approval) -- see actionableBookingsCountProvider.
    // Never a fabricated notification number.
    final actionableBookings = ref.watch(actionableBookingsCountProvider);
    final simpleMode = ref.watch(simpleModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // The admin-configured bar. The route tree itself is fixed, so this decides
    // only which branches are reachable *from the bar* — never which routes
    // exist. A hidden destination is still reachable by deep link.
    final tabs = ref.watch(visibleNavTabsProvider);
    final position = tabs.indexWhere(
      (entry) => entry.tab.branch == navigationShell.currentIndex,
    );
    // Material 3 requires an in-range selection. A branch reached while hidden
    // from the bar (deep link or an in-app button) has no bar position, so the
    // first destination is highlighted instead of asserting.
    final selectedIndex = position >= 0 ? position : 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151A2C) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : 4),
          child: NavigationBar(
            // Keep labels visible so first-time users can understand each
            // destination without relying on platform-specific icon
            // knowledge. Destinations and routes are unchanged.
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: simpleMode ? 76 : null,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              final branch = tabs[index].tab.branch;
              navigationShell.goBranch(
                branch,
                initialLocation: branch == navigationShell.currentIndex,
              );
            },
            destinations: [
              for (final entry in tabs)
                NavigationDestination(
                  key: ValueKey('shell_${entry.tab.id}'),
                  icon: _navTabIcon(
                    entry,
                    actionableBookings: actionableBookings,
                    selected: false,
                  ),
                  selectedIcon: _navTabIcon(
                    entry,
                    actionableBookings: actionableBookings,
                    selected: true,
                  ),
                  label: navTabLabel(entry, l10n, isCompact: isCompact),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernShell(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final simpleMode = ref.watch(simpleModeProvider);
    const navStyle = ShellNavStyle.modern;
    final visible = visibleShellDestinations(
      ref.watch(featureRegistryProvider),
      style: navStyle,
    );
    final selected = selectedShellIndex(
      currentBranch: navigationShell.currentIndex,
      visible: visible,
    );
    const modern = true;
    final theme = Theme.of(context);
    final navBar = NavigationBar(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppTheme.brand.withValues(alpha: 0.12),
      height: 72,
      labelBehavior: simpleMode || modern
          ? NavigationDestinationLabelBehavior.alwaysShow
          : NavigationDestinationLabelBehavior.onlyShowSelected,
      selectedIndex: selected,
      onDestinationSelected: (index) {
        final branch = visible[index].branchIndex;
        navigationShell.goBranch(
          branch,
          initialLocation: branch == navigationShell.currentIndex,
        );
      },
      destinations: [
        for (final item in visible)
          TestId(
            E2eIds.nav(item.id),
            child: NavigationDestination(
              key: ValueKey('shell_${item.id}'),
              icon: Icon(_shellIcon(item.id, selected: false)),
              selectedIcon: Icon(_shellIcon(item.id, selected: true)),
              label: _shellLabel(item.id, l10n, modern: modern),
            ),
          ),
      ],
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppTheme.brand.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 12,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? AppTheme.brand
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? AppTheme.brand
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          child: navBar,
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

IconData _shellIcon(String id, {required bool selected}) {
  return switch (id) {
    'map' => selected ? Icons.map_rounded : Icons.map_outlined,
    'search' => selected ? Icons.search_rounded : Icons.search_outlined,
    'bookings' =>
      selected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined,
    'profile' => selected ? Icons.person_rounded : Icons.person_outline_rounded,
    'saved' =>
      selected ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
    'chat' =>
      selected ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded,
    _ => selected ? Icons.home_rounded : Icons.home_outlined,
  };
}

String _shellLabel(String id, AppLocalizations l10n, {bool modern = false}) {
  return switch (id) {
    'map' => l10n.navMap,
    'search' => modern ? l10n.navExplore : l10n.navSearch,
    'chat' => l10n.navChat,
    'bookings' => l10n.navBookings,
    'profile' => l10n.navProfile,
    'saved' => l10n.navSaved,
    _ => l10n.navHome,
  };
}

// Temporary placeholder replaced with a real screen in a later milestone.
class ProfilePlaceholderScreen extends StatelessWidget {
  const ProfilePlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Profile (M7)')));
  }
}
