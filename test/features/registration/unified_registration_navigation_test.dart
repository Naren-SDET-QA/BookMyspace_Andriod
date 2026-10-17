import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/registration/presentation/unified_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final module in unifiedRegistrationModules) {
    testWidgets('${module.key} opens its real registration route', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/register',
        routes: [
          GoRoute(
            path: '/register',
            builder: (_, __) => const UnifiedRegistrationScreen(),
          ),
          GoRoute(
            path: AppRoutes.ownerRegistration,
            builder: (_, __) =>
                const Scaffold(body: Text('Owner OTP registration')),
          ),
          GoRoute(
            path: AppRoutes.moduleRegistration,
            builder: (_, state) => Scaffold(
              body: Text('Module ${state.pathParameters['module']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(module.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(module.title));
      await tester.pumpAndSettle();
      expect(
        find.text(
          module.key == 'venue_owner'
              ? 'Owner OTP registration'
              : 'Module ${module.key}',
        ),
        findsOneWidget,
      );
    });
  }
}
