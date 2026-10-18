import 'package:bookmyspace/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'catalog can be discovered by guests while checkout and account routes stay protected',
    () {
      expect(
        resolveAppRedirect(
          location: AppRoutes.marketplace,
          currentUser: null,
          authReady: true,
        ),
        isNull,
      );
      for (final path in [
        AppRoutes.bookings,
        '/bookings/fixture/pay',
        AppRoutes.profile,
        AppRoutes.adminDashboard,
      ]) {
        expect(
          resolveAppRedirect(
            location: path,
            currentUser: null,
            authReady: true,
          ),
          AppRoutes.login,
        );
      }
    },
  );
}
