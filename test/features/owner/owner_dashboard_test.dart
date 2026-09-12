import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner/domain/owner.dart';
import 'package:bookmyspace/features/owner/presentation/owner_providers.dart';
import 'package:bookmyspace/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:bookmyspace/features/owner_venues/presentation/providers/owner_venue_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';

void main() {
  testWidgets('owner dashboard shows real venue and booking counts',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'owner-1', email: 'o@test.com'),
            ),
          ),
          currentOwnerProvider.overrideWith(
            (ref) async => const Owner(
              id: 'op1',
              userId: 'owner-1',
              email: 'o@test.com',
              name: 'Owner One',
            ),
          ),
          myVenuesProvider.overrideWith(
            (ref) async => const [
              Venue(
                id: 'v1',
                name: 'Hall One',
                latitude: 0,
                longitude: 0,
              ),
            ],
          ),
          ownerVenueBookingsProvider.overrideWith(
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
                amount: 1000,
                taxAmount: 180,
                totalAmount: 1180,
                venueName: 'Hall One',
              ),
              Booking(
                id: 'b2',
                bookingRef: 'BMS-2',
                venueId: 'v1',
                slotId: 's1',
                bookDate: DateTime(2026, 9, 21),
                startTime: '09:00:00',
                endTime: '12:00:00',
                status: BookingStatus.pending,
                amount: 1000,
                taxAmount: 180,
                totalAmount: 1180,
                venueName: 'Hall One',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: OwnerDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owner One'), findsOneWidget);
    expect(find.text('Venue bookings'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('1180'), findsOneWidget);
  });
}
