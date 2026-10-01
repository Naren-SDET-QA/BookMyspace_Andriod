import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Venues Route Redirect & Query Param Tests', () {
    test('resolveAppRedirect redirects /venues?category=function_halls to /search?category=function_halls', () {
      final target = resolveAppRedirect(
        location: '/venues?category=function_halls',
        currentUser: const AuthUser(id: 'u1', email: 'test@bms.com'),
        authReady: true,
      );
      expect(target, '${AppRoutes.search}?category=function_halls');
    });

    test('resolveAppRedirect redirects /venues without query to /search', () {
      final target = resolveAppRedirect(
        location: '/venues',
        currentUser: const AuthUser(id: 'u1', email: 'test@bms.com'),
        authReady: true,
      );
      expect(target, AppRoutes.search);
    });

    test('resolveAppRedirect preserves individual venue path /venues/v-123 without redirecting to search', () {
      final target = resolveAppRedirect(
        location: '/venues/v-123',
        currentUser: const AuthUser(id: 'u1', email: 'test@bms.com'),
        authReady: true,
      );
      expect(target, null);
    });

    test('specRouteAliases and router routes map /venues to search preserving query parameters', () {
      final targetWithFilter = resolveAppRedirect(
        location: '/venues?category=hotel_rooms&city=Hyderabad',
        currentUser: const AuthUser(id: 'u1', email: 'test@bms.com'),
        authReady: true,
      );
      expect(targetWithFilter, '${AppRoutes.search}?category=hotel_rooms&city=Hyderabad');
    });
  });

  group('Display all screens preview', () {
    const customer = AuthUser(id: 'u1', email: 'test@bms.com');

    test('a customer can open an owner place while preview is on', () {
      expect(
        resolveAppRedirect(
          location: '/owner/payments',
          currentUser: customer,
          authReady: true,
          allowPreviewAllScreens: true,
        ),
        isNull,
      );
    });

    test('a customer is sent to profile for that owner place when preview is off', () {
      expect(
        resolveAppRedirect(
          location: '/owner/payments',
          currentUser: customer,
          authReady: true,
        ),
        AppRoutes.profile,
      );
    });

    test('phase-one routes stay on home while preview is on', () {
      expect(
        resolveAppRedirect(
          location: '/sports',
          currentUser: customer,
          authReady: true,
          allowPreviewAllScreens: true,
        ),
        AppRoutes.home,
      );
    });
  });
}
