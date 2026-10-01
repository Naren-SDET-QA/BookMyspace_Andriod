import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/app_role.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/role_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/profile_screen.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'mock_auth_repository.dart';

void main() {
  testWidgets('profile metrics use live booking and saved counts',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          currentUserRolesProvider.overrideWith(
            (ref) async => {AppRole.customer},
          ),
          myBookingsProvider.overrideWith(
            (ref) async => [
              Booking(
                id: 'b1',
                bookingRef: 'BMS-1',
                venueId: 'v1',
                slotId: 's1',
                bookDate: DateTime(2026, 9, 20),
                startTime: '09:00:00',
                endTime: '12:00:00',
                status: BookingStatus.confirmed,
                amount: 100,
                taxAmount: 18,
                totalAmount: 118,
              ),
            ],
          ),
          savedVenuesProvider.overrideWith(
            (ref) async => const [
              Venue(id: 'v1', name: 'Hall', latitude: 0, longitude: 0),
              Venue(id: 'v2', name: 'Studio', latitude: 0, longitude: 0),
            ],
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 active'), findsOneWidget);
    expect(find.text('2 saved'), findsOneWidget);
    expect(find.text('₹2,500'), findsNothing);
    expect(find.text('Wallet'), findsNothing);
    expect(find.text('Admin console'), findsNothing);
  });
}
