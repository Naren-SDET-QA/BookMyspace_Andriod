import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const customer = AuthUser(id: 'customer');
  const owner = AuthUser(id: 'owner', role: UserRole.venueOwner);

  test('Phase-1 routes without PROD backend contracts redirect home', () {
    const customerRoutes = [
      '/pg',
      '/pg/property-1',
      '/stays',
      '/stays/property-1',
      '/stays/bookings/mine',
      '/meeting-rooms',
      '/meeting-rooms/room-1',
      '/meeting-rooms/room-1/book',
      '/sports',
      '/sports/venue-1',
      '/sports/venue-1/book',
      '/commerce/reference-1/pay',
      '/invoices/invoice-1',
      '/registration/forms/form-1/fill',
    ];
    const ownerRoutes = [
      '/owner/stays',
      '/owner/meeting-rooms',
      '/owner/sports',
      '/owner/invoice-settings',
      '/owner/registration-forms',
    ];

    for (final route in customerRoutes) {
      expect(
        resolveAppRedirect(
          location: route,
          currentUser: customer,
          authReady: true,
        ),
        AppRoutes.home,
        reason: route,
      );
    }
    for (final route in ownerRoutes) {
      expect(
        resolveAppRedirect(
          location: route,
          currentUser: owner,
          authReady: true,
        ),
        AppRoutes.home,
        reason: route,
      );
    }
  });

  test(
    'existing PROD booking, module registration, and owner flows stay open',
    () {
      const ownerRoutes = [
        '/owner/availability',
        '/owner/offline-booking',
        '/owner/payments',
      ];
      for (final route in ownerRoutes) {
        expect(
          resolveAppRedirect(
            location: route,
            currentUser: owner,
            authReady: true,
          ),
          isNull,
          reason: route,
        );
      }

      expect(
        resolveAppRedirect(
          location: '/bookings/booking-1/pay',
          currentUser: customer,
          authReady: true,
        ),
        isNull,
      );
      expect(
        resolveAppRedirect(
          location: AppRoutes.unifiedRegistration,
          currentUser: null,
          authReady: true,
        ),
        isNull,
      );
    },
  );

  test('unavailable routes fail closed while authentication is resolving', () {
    expect(
      resolveAppRedirect(
        location: '/commerce/reference-1/pay',
        currentUser: null,
        authReady: false,
      ),
      AppRoutes.home,
    );
  });

  test(
    'venue claims page is admin-only and distinct from discovery review',
    () {
      const admin = AuthUser(id: 'admin', role: UserRole.admin);
      expect(
        resolveAppRedirect(
          location: AppRoutes.adminVenueClaims,
          currentUser: admin,
          authReady: true,
        ),
        isNull,
      );
      expect(
        resolveAppRedirect(
          location: AppRoutes.adminVenueDiscoveryReview,
          currentUser: admin,
          authReady: true,
        ),
        isNull,
      );
    },
  );
}
