import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/booking_screen.dart';
import 'package:bookmyspace/features/venues/domain/listing_template.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_booking_repository.dart';

void main() {
  const venue = Venue(
    id: 'v1',
    name: 'Sunrise Function Hall',
    slug: 'sunrise-function-hall',
    city: 'Hyderabad',
    latitude: 17.3850,
    longitude: 78.4867,
    capacity: 600,
    pricingBaseAmount: 45000,
    category: VenueCategory(
      id: 'c1',
      slug: 'function_hall',
      name: 'Function Hall',
      listingConfig: ListingTemplateConfig(
        templateId: 'hall',
        fields: [
          ListingFieldDefinition(
            key: 'date',
            label: 'Date',
            type: ListingFieldType.date,
            required: true,
          ),
          ListingFieldDefinition(
            key: 'guests',
            label: 'Guests',
            type: ListingFieldType.number,
            required: true,
          ),
          ListingFieldDefinition(
            key: 'event_type',
            label: 'Event type',
            type: ListingFieldType.dropdown,
            required: true,
            options: ['Wedding', 'Reception'],
          ),
        ],
      ),
    ),
  );

  testWidgets('booking requires event type before the confirm dialog',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(
            MockBookingRepository(
              slots: const [
                SlotAvailability(
                  slotId: 's1',
                  label: 'Morning',
                  startTime: '09:00:00',
                  endTime: '13:00:00',
                  priceAmount: 45000,
                  isAvailable: true,
                  reason: 'available',
                ),
              ],
            ),
          ),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: BookingScreen(venue: venue),
          localizationsDelegates: [
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

    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book & Pay').last);
    await tester.pumpAndSettle();

    expect(find.text('Please enter Event type'), findsOneWidget);
    expect(find.text('Confirm Booking'), findsNothing);
  });

  testWidgets('booking confirm dialog shows slot, guests and event type',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(
            MockBookingRepository(
              slots: const [
                SlotAvailability(
                  slotId: 's1',
                  label: 'Morning',
                  startTime: '09:00:00',
                  endTime: '13:00:00',
                  priceAmount: 45000,
                  isAvailable: true,
                  reason: 'available',
                ),
              ],
            ),
          ),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: BookingScreen(venue: venue),
          localizationsDelegates: [
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

    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Event type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wedding').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book & Pay').last);
    await tester.pumpAndSettle();

    expect(find.text('Confirm Booking'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsWidgets);
    expect(find.text('Morning'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Wedding'), findsWidgets);
  });
}
