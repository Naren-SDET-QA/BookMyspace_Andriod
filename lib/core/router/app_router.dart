import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../features/accommodations/domain/accommodation.dart';
import '../../features/accommodations/presentation/screens/accommodation_detail_screen.dart';
import '../../features/accommodations/presentation/screens/accommodation_list_screen.dart';
import '../../features/accommodations/presentation/screens/stay_management_screens.dart';
import '../../features/admin/presentation/screens/admin_app_sections_screen.dart';
import '../../features/admin/presentation/screens/admin_audit_screen.dart';
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
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/booking/domain/booking.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/invoice_screen.dart';
import '../../features/booking/presentation/screens/my_bookings_screen.dart';
import '../../features/business/presentation/screens/business_plan_configuration_screen.dart';
import '../../features/business/presentation/screens/business_pricing_configuration_screen.dart';
import '../../features/checkin/presentation/screens/qr_check_in_screen.dart';
import '../../features/courses/presentation/screens/course_detail_screen.dart';
import '../../features/courses/presentation/screens/courses_list_screen.dart';
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
import '../../features/owner/presentation/screens/registration_field_configuration_screen.dart';
import '../../features/owner/presentation/screens/venue_optimizer_screen.dart';
import '../../features/owner_bookings/presentation/screens/create_offline_booking_screen.dart';
import '../../features/owner_bookings/presentation/screens/owner_bookings_screen.dart';
import '../../features/owner_bookings/presentation/screens/owner_calendar_screen.dart';
import '../../features/owner_venues/presentation/screens/create_venue_screen.dart';
import '../../features/owner_venues/presentation/screens/media_manager_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_availability_screen.dart';
import '../../features/owner_venues/presentation/screens/owner_venues_screen.dart';
import '../../features/payments/presentation/screens/booking_success_screen.dart';
import '../../features/payments/presentation/screens/commerce_payment_screen.dart';
import '../../features/payments/presentation/screens/payment_health_screen.dart';
import '../../features/payments/presentation/screens/payment_history_screen.dart';
import '../../features/payments/presentation/screens/payment_screen.dart';
import '../../features/payments/presentation/screens/receipt_screen.dart';
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
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/theme_customizer_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/sports/presentation/screens/sports_screens.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/venue_discovery/infrastructure/supabase_discovery_repository.dart';
import '../../features/venue_discovery/presentation/screens/venue_discovery_screen.dart';
import '../../features/venues/domain/venue.dart';
import '../../features/venues/presentation/screens/venue_details_screen.dart';
import '../config/settings_controller.dart';
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
  static const commercePayment = '/commerce/:id/pay';
  static const bookingResult = '/bookings/:id/status';
  static const bookingReceipt = '/bookings/:id/receipt';
  static const eventsList = '/events';
  static const eventDetails = '/events/:id';
  static const coursesList = '/courses';
  static const courseDetails = '/courses/:id';
  static const pgList = '/pg';
  static const pgDetails = '/pg/:id';
  static const staysList = '/stays';
  static const stayDetails = '/stays/:id';
  static const myStays = '/stays/bookings/mine';
  static const notifications = '/notifications';
  static const analytics = '/analytics';
  static const support = '/support';
  static const adminAudit = '/admin/audit';
  static const adminDashboard = '/admin';
  static const adminListings = '/admin/listings';
  static const adminVenueDiscoveryReview = '/admin/venue-discovery-review';
  static const adminCategories = '/admin/categories';
  static const adminAppSections = '/admin/app-sections';
  static const adminFeatureConfiguration = '/admin/features';
  static const adminTenantConfiguration = '/admin/tenant-configuration';
  static const adminBookings = '/admin/bookings';
  static const adminPayments = '/admin/payments';
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
  static const assistant = '/assistant';
  static const chat = '/chat';
  static const homeModern = '/home-modern';
  static const checkIn = '/check-in';
  static const institutesList = '/institutes';
  static const instituteDetails = '/institutes/:id';
  static const ownerInstitute = '/owner/institute';
  static const themeCustomizer = '/theme';
  static const ownerRegistration = '/owner/register';
  static const ownerDashboard = '/owner';
  static const ownerVenues = '/owner/venues';
  static const ownerVenueCreate = '/owner/venues/create';
  static const ownerVenueEdit = '/owner/venues/:id/edit';
  static const ownerVenueMedia = '/owner/venues/:id/media';
  static const ownerVenueAvailability = '/owner/venues/:id/availability';
  static const ownerBookings = '/owner/bookings';
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
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

/// Creates the application router. [initialLocation] is overridable in tests.
///
/// When [currentUser] is provided, protected routes redirect to the login
/// screen for unauthenticated users, and signed-in users are bounced away from
/// the onboarding/login screens. A `null` [currentUser] disables gating.
GoRouter createAppRouter({
  String initialLocation = AppRoutes.shell,
  AuthUser? currentUser,
  bool authReady = true,
  bool allowUnauthenticatedTestAccess = false,
  FeatureRegistry? features,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (context, state) => resolveAppRedirect(
      location: state.matchedLocation,
      currentUser: currentUser,
      authReady: authReady,
      allowUnauthenticatedTestAccess: allowUnauthenticatedTestAccess,
      features: features,
    ),
    routes: [
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
            const HomeScreen(forceModernLayout: true),
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
        path: AppRoutes.adminDashboard,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminDashboardScreen(),
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
        path: AppRoutes.adminCategories,
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
        path: AppRoutes.adminPayments,
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
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.support,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SupportTicketsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAudit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdminAuditScreen(),
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
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerVenues,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerVenuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerVenueCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateVenueScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerVenueEdit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            CreateVenueScreen(venueId: state.pathParameters['id']),
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
        path: AppRoutes.ownerBookings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OwnerBookingsScreen(),
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
            ? BookingSuccessScreen(booking: state.extra! as Booking)
            : const MyBookingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookingReceipt,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ReceiptScreen(bookingId: state.pathParameters['id'] ?? ''),
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
          // Map is a primary destination (parity with the Android reference
          // app's 5-item bottom nav: Home/Map/Search/Bookings/Profile).
          // Notifications and Courses moved to standalone pushed routes --
          // matching Android, where they are secondary destinations reached
          // from Home rather than the bottom bar.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const SearchMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) {
                  final extra = state.extra;
                  final category = extra is Map<String, dynamic>
                      ? extra['category'] as String?
                      : null;
                  final section = extra is Map<String, dynamic>
                      ? extra['section'] as String?
                      : null;
                  final query = extra is Map<String, dynamic>
                      ? extra['query'] as String?
                      : null;
                  final intent = extra is Map<String, dynamic>
                      ? extra['intent'] as AiSearchIntent?
                      : null;
                  return SearchScreen(
                    initialCategory: category,
                    initialSection: section,
                    initialQuery: query,
                    initialIntent: intent,
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
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.saved,
                builder: (context, state) => const SavedScreen(),
              ),
            ],
          ),
          // Chat tab (modern bottom-nav style): the existing AI assistant
          // screen hosted inside the shell. /assistant stays a pushed route.
          StatefulShellBranch(
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
    final isAdminRoute =
        location == AppRoutes.adminDashboard || location.startsWith('/admin/');
    final isOwnerRoute =
        location.startsWith('/owner') || location == AppRoutes.analytics;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final simpleMode = ref.watch(simpleModeProvider);
    final navStyle = ShellNavStyle.fromSetting(
      ref.watch(adminSettingsProvider).valueOrNull?.home['bottom_nav_style'],
    );
    final visible = visibleShellDestinations(
      ref.watch(featureRegistryProvider),
      style: navStyle,
    );
    final selected = selectedShellIndex(
      currentBranch: navigationShell.currentIndex,
      visible: visible,
    );
    final modern = navStyle == ShellNavStyle.modern;
    final theme = Theme.of(context);
    final navBar = NavigationBar(
        backgroundColor: modern ? theme.colorScheme.surface : null,
        surfaceTintColor: modern ? Colors.transparent : null,
        indicatorColor: modern
            ? AppTheme.brand.withValues(alpha: 0.12)
            : null,
        height: modern ? 72 : null,
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
      bottomNavigationBar: modern
          ? DecoratedBox(
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
            )
          : navBar,
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
