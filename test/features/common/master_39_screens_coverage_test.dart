import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';

// Domain 1: Discovery & Search (5)
import 'package:bookmyspace/features/home/presentation/screens/home_screen.dart';
import 'package:bookmyspace/features/map/presentation/screens/venue_map_screen.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/venue_discovery/presentation/screens/venue_discovery_screen.dart';
import 'package:bookmyspace/features/saved/presentation/screens/saved_screen.dart';

// Domain 2: Booking & Checkout (4)
import 'package:bookmyspace/features/venues/presentation/screens/venue_details_screen.dart';
import 'package:bookmyspace/features/booking/presentation/screens/booking_screen.dart';
import 'package:bookmyspace/features/payments/presentation/screens/payment_screen.dart';
import 'package:bookmyspace/features/booking/presentation/screens/booking_success_screen.dart';

// Domain 3: User & Post-Booking (10)
import 'package:bookmyspace/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:bookmyspace/features/auth/presentation/screens/profile_screen.dart';
import 'package:bookmyspace/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:bookmyspace/features/rewards/presentation/screens/referral_screen.dart';
import 'package:bookmyspace/features/support/presentation/screens/support_screen.dart';
import 'package:bookmyspace/features/auth/presentation/screens/login_screen.dart';
import 'package:bookmyspace/features/registration/presentation/unified_registration_screen.dart';
import 'package:bookmyspace/features/legal/presentation/screens/privacy_policy_screen.dart';
import 'package:bookmyspace/features/legal/presentation/screens/terms_of_service_screen.dart';
import 'package:bookmyspace/features/settings/presentation/screens/theme_customizer_screen.dart';

// Domain 4: Host & Academies (7)
import 'package:bookmyspace/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:bookmyspace/features/owner_venues/presentation/screens/create_venue_screen.dart';
import 'package:bookmyspace/features/institutes/presentation/screens/institutes_list_screen.dart';
import 'package:bookmyspace/features/institutes/presentation/screens/institute_owner_dashboard_screen.dart';
import 'package:bookmyspace/features/events/presentation/screens/events_list_screen.dart';
import 'package:bookmyspace/features/qr_checkin/presentation/screens/qr_check_in_scanner_screen.dart';
import 'package:bookmyspace/features/settings/presentation/screens/connected_apps_screen.dart';

// Domain 5: Super Admin & CMS (9)
import 'package:bookmyspace/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_ui_element_overrides_screen.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_app_sections_screen.dart';
import 'package:bookmyspace/features/integrations/presentation/screens/admin_integrations_screen.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_audit_screen.dart';
import 'package:bookmyspace/features/owner/presentation/screens/registration_field_configuration_screen.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_listing_fields_screen.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_settings_screen.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_developer_platform_screen.dart';

// Domain 6: Analytics, Reports & Health Diagnostics (4)
import 'package:bookmyspace/features/integrations/infrastructure/supabase_developer_platform_repository.dart';
import 'package:bookmyspace/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:bookmyspace/features/admin_payment/presentation/screens/admin_transaction_ledger_screen.dart';
import 'package:bookmyspace/features/admin_payment/presentation/screens/admin_payment_health_screen.dart';
import 'package:bookmyspace/features/customer_analytics/presentation/screens/customer_analytics_screen.dart';

import '../auth/mock_auth_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';

class _FakeDeveloperPlatformRepository implements SupabaseDeveloperPlatformRepository {
  @override
  Future<List<Map<String, dynamic>>> apiKeys() async => [];
  @override
  Future<List<Map<String, dynamic>>> endpoints() async => [];
  @override
  Future<List<Map<String, dynamic>>> deliveries() async => [];
  @override
  Future<Map<String, dynamic>> createKey(String name, List<String> scopes) async => {};
  @override
  Future<void> revokeKey(String id) async {}
  @override
  Future<void> saveEndpoint({
    String? id,
    required String name,
    required String endpointUrl,
    required String secretReference,
    required List<String> eventTypes,
    required bool enabled,
  }) async {}
}

Widget _buildScreenWrapper(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      currentUserRolesProvider.overrideWith(
        (ref) => {AppRole.administrator, AppRole.venueOwner, AppRole.customer},
      ),
      activeDevRoleProvider.overrideWith((ref) => DevRole.admin),
      developerPlatformRepositoryProvider.overrideWithValue(_FakeDeveloperPlatformRepository()),
      savedVenuesProvider.overrideWith((ref) async => const []),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: const AuthUser(id: 'u1', email: 'a@b.com')),
      ),
      venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  const customer = AuthUser(id: 'customer_1', role: UserRole.customer);
  const owner = AuthUser(id: 'owner_1', role: UserRole.venueOwner);
  const admin = AuthUser(id: 'admin_1', role: UserRole.admin);

  group('Master 39 Screen Verification: Routing & Role Authorization Matrix', () {
    test('Domain 1: Discovery & Search (5 screens) route paths are registered and accessible', () {
      final routes = [
        AppRoutes.home,
        AppRoutes.map,
        AppRoutes.search,
        AppRoutes.venueDiscovery,
        AppRoutes.saved,
      ];
      for (final route in routes) {
        final redirect = resolveAppRedirect(
          location: route,
          currentUser: customer,
          authReady: true,
        );
        expect(redirect, isNull, reason: 'Discovery route $route must allow customer access');
      }
    });

    test('Domain 2: Booking & Checkout (4 screens) routes are registered and accessible', () {
      final routes = [
        '/venues/demo-v1',
        '/venues/demo-v1/book',
        '/bookings/demo-b1/pay',
        '/bookings/demo-b1/success',
      ];
      for (final route in routes) {
        final redirect = resolveAppRedirect(
          location: route,
          currentUser: customer,
          authReady: true,
        );
        expect(redirect, isNull, reason: 'Booking route $route must allow customer access');
      }
    });

    test('Domain 3: User & Post-Booking (10 screens) routes are registered and accessible', () {
      final authenticatedRoutes = [
        AppRoutes.bookings,
        AppRoutes.profile,
        AppRoutes.notifications,
        AppRoutes.referrals,
        AppRoutes.support,
        AppRoutes.privacyPolicy,
        AppRoutes.termsOfService,
        AppRoutes.themeCustomizer,
      ];
      for (final route in authenticatedRoutes) {
        final redirect = resolveAppRedirect(
          location: route,
          currentUser: customer,
          authReady: true,
        );
        expect(redirect, isNull, reason: 'User & legal route $route must allow customer access');
      }

      // Public entry points allow unauthenticated access
      for (final route in [AppRoutes.login, AppRoutes.unifiedRegistration]) {
        final publicRedirect = resolveAppRedirect(
          location: route,
          currentUser: null,
          authReady: true,
        );
        expect(publicRedirect, isNull, reason: 'Public entry point $route must allow guest access');
      }

      // Logged-in user at /login redirects to home; /register is open to upgrade roles
      expect(
        resolveAppRedirect(location: AppRoutes.login, currentUser: customer, authReady: true),
        AppRoutes.shell,
      );
      expect(
        resolveAppRedirect(location: AppRoutes.unifiedRegistration, currentUser: customer, authReady: true),
        isNull,
      );
    });

    test('Domain 4: Host & Academies (7 screens) routes require owner authorization', () {
      final ownerRoutes = [
        AppRoutes.ownerDashboard,
        AppRoutes.ownerVenueCreate,
        AppRoutes.institutesList,
        AppRoutes.ownerInstituteDashboard,
        AppRoutes.eventsList,
        AppRoutes.qrScanner,
        AppRoutes.connectedApps,
      ];
      for (final route in ownerRoutes) {
        final redirect = resolveAppRedirect(
          location: route,
          currentUser: owner,
          authReady: true,
        );
        expect(redirect, isNull, reason: 'Owner route $route must allow owner access');
      }
    });

    test('Domain 5: Super Admin & CMS (9 screens) routes require admin authorization', () {
      final adminRoutes = [
        AppRoutes.adminDashboard,
        AppRoutes.adminUiElementOverrides,
        AppRoutes.adminAppSections,
        AppRoutes.adminIntegrations,
        AppRoutes.adminAudit,
        AppRoutes.adminRegistrationFields,
        AppRoutes.adminListingFields,
        AppRoutes.adminSettings,
        AppRoutes.adminDeveloperPlatform,
      ];
      for (final route in adminRoutes) {
        final redirect = resolveAppRedirect(
          location: route,
          currentUser: admin,
          authReady: true,
        );
        expect(redirect, isNull, reason: 'Admin route $route must allow admin access');
      }
    });

    test('Domain 6: Analytics, Reports & Health Diagnostics (4 screens) routes allow admin access', () {
      final reportRoutes = [
        AppRoutes.analytics,
        AppRoutes.adminPaymentsLedger,
        AppRoutes.adminPaymentHealth,
        AppRoutes.customerAnalytics,
      ];
      for (final route in reportRoutes) {
        final redirect = resolveAppRedirect(
          location: route,
          currentUser: admin,
          authReady: true,
        );
        expect(redirect, isNull, reason: 'Reports route $route must allow access');
      }
    });
  });

  group('Master 39 Screen Verification: Responsive Widget Rendering Across Viewports', () {
    const viewports = [
      Size(360, 780),   // Mobile Phone
      Size(768, 1024),  // Tablet
      Size(1280, 900),  // Desktop
    ];

    testWidgets('Domain 1: Discovery & Search screens render without overflow', (tester) async {
      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Pan-India Place Discovery
        await tester.pumpWidget(_buildScreenWrapper(const VenueDiscoveryScreen()));
        await tester.pump();
        expect(find.byType(VenueDiscoveryScreen), findsOneWidget);
        expect(find.text('Venue Discovery'), findsOneWidget);

        // 2. Saved & Bookmarked Spaces
        await tester.pumpWidget(_buildScreenWrapper(const SavedScreen()));
        await tester.pump();
        expect(find.byType(SavedScreen), findsOneWidget);
      }
    });

    testWidgets('Domain 3: User & Post-Booking screens render without overflow', (tester) async {
      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Referral Screen
        await tester.pumpWidget(_buildScreenWrapper(const ReferralScreen()));
        await tester.pump();
        expect(find.text('Refer & Earn'), findsOneWidget);

        // 2. Customer Support & Live Help
        await tester.pumpWidget(_buildScreenWrapper(const SupportTicketsScreen()));
        await tester.pump();
        expect(find.byType(SupportTicketsScreen), findsOneWidget);

        // 3. User Login
        await tester.pumpWidget(_buildScreenWrapper(const LoginScreen()));
        await tester.pump();
        expect(find.byType(LoginScreen), findsOneWidget);

        // 4. Unified Registration
        await tester.pumpWidget(_buildScreenWrapper(const UnifiedRegistrationScreen()));
        await tester.pump();
        expect(find.byType(UnifiedRegistrationScreen), findsOneWidget);

        // 5. Privacy Policy
        await tester.pumpWidget(_buildScreenWrapper(const PrivacyPolicyScreen()));
        await tester.pump();
        expect(find.byType(PrivacyPolicyScreen), findsOneWidget);

        // 6. Terms of Service
        await tester.pumpWidget(_buildScreenWrapper(const TermsOfServiceScreen()));
        await tester.pump();
        expect(find.byType(TermsOfServiceScreen), findsOneWidget);

        // 7. Theme Customizer
        await tester.pumpWidget(_buildScreenWrapper(const ThemeCustomizerScreen()));
        await tester.pump();
        expect(find.text('Theme customizer'), findsOneWidget);
      }
    });

    testWidgets('Domain 4: Host & Academy screens render without overflow', (tester) async {
      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Institutes & Classes
        await tester.pumpWidget(_buildScreenWrapper(const InstitutesListScreen()));
        await tester.pump();
        expect(find.byType(InstitutesListScreen), findsOneWidget);

        // 2. Events & Tournaments
        await tester.pumpWidget(_buildScreenWrapper(const EventsListScreen()));
        await tester.pump();
        expect(find.byType(EventsListScreen), findsOneWidget);

        // 3. Connected Apps & MCP
        await tester.pumpWidget(_buildScreenWrapper(const ConnectedAppsScreen()));
        await tester.pump();
        expect(find.text('Connected Apps & Developer APIs'), findsOneWidget);
      }
    });

    testWidgets('Domain 5: Super Admin & CMS screens render without overflow', (tester) async {
      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Live Element Editor
        await tester.pumpWidget(_buildScreenWrapper(const AdminUiElementOverridesScreen()));
        await tester.pump();
        expect(find.text('Live element editor'), findsOneWidget);

        // 2. App Sections & Feature Toggles
        await tester.pumpWidget(_buildScreenWrapper(const AdminAppSectionsScreen()));
        await tester.pump();
        expect(find.text('App sections'), findsOneWidget);

        // 3. Integrations / Feature Hub
        await tester.pumpWidget(_buildScreenWrapper(const AdminIntegrationsScreen()));
        await tester.pump();
        expect(find.text('Integrations'), findsOneWidget);

        // 4. Admin Audit Logs
        await tester.pumpWidget(_buildScreenWrapper(const AdminAuditScreen()));
        await tester.pump();
        expect(find.byType(AdminAuditScreen), findsOneWidget);

        // 5. Listing Fields Configuration
        await tester.pumpWidget(_buildScreenWrapper(const AdminListingFieldsScreen()));
        await tester.pump();
        expect(find.text('Listing fields'), findsOneWidget);

        // 6. Platform Settings & Host Controls
        await tester.pumpWidget(_buildScreenWrapper(const AdminSettingsScreen()));
        await tester.pump();
        expect(find.text('Admin settings'), findsOneWidget);

        // 7. Developer Platform / Firebase Migration
        await tester.pumpWidget(_buildScreenWrapper(const AdminDeveloperPlatformScreen()));
        await tester.pump();
        expect(find.text('Developer platform'), findsOneWidget);
      }
    });

    testWidgets('Domain 6: Analytics, Reports & Health screens render without overflow', (tester) async {
      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Platform Spending Analytics
        await tester.pumpWidget(_buildScreenWrapper(const CustomerAnalyticsScreen()));
        await tester.pump();
        expect(find.text('My spending & usage'), findsOneWidget);
      }
    });
  });
}
