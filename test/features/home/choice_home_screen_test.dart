import 'package:bookmyspace/features/admin/domain/admin_settings.dart';
import 'package:bookmyspace/features/admin/presentation/admin_settings_providers.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/home/presentation/screens/choice_home_screen.dart';
import 'package:bookmyspace/features/home/presentation/screens/home_layout_switch.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';

void main() {
  const venue = Venue(
    id: 'hall-1',
    name: 'Royal Palace Hall',
    city: 'Hyderabad',
    latitude: 17.4,
    longitude: 78.4,
    price: 50000,
    avgRating: 4.8,
  );

  Future<void> pump(WidgetTester tester, String? layout) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminSettingsProvider.overrideWith(
            (ref) async => AdminSettings(
              home: {if (layout != null) 'home_layout': layout},
            ),
          ),
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          popularVenuesProvider.overrideWith((ref) async => const [venue]),
          nearbyVenuesProvider.overrideWith((ref) async => const <Venue>[]),
          venueCategoriesProvider.overrideWith(
            (ref) => Stream.value(const <VenueCategory>[]),
          ),
        ],
        child: const MaterialApp(home: HomeLayoutSwitch()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('moment home is the light Your Space page', (tester) async {
    await pump(tester, 'moment');
    expect(find.byKey(const Key('choice-home-moment')), findsOneWidget);
    expect(find.textContaining('Your Space'), findsOneWidget);
    expect(find.text('Featured Near You'), findsOneWidget);
    expect(find.text('Royal Palace Hall'), findsOneWidget);
    expect(find.text('Function Halls'), findsOneWidget);
    expect(find.text('PGs & Stays'), findsOneWidget);
    expect(find.text('Classes'), findsOneWidget);
    expect(find.byType(ChoiceHomeScreen), findsOneWidget);
  });

  testWidgets('life home is the dark Spaces for Your Life page', (tester) async {
    await pump(tester, 'life');
    expect(find.byKey(const Key('choice-home-life')), findsOneWidget);
    expect(find.textContaining('Spaces for'), findsOneWidget);
    expect(find.text('Trending Spaces'), findsOneWidget);
    expect(find.text('Book. Learn. Stay. Celebrate.'), findsOneWidget);
    expect(find.byType(ChoiceHomeScreen), findsOneWidget);
  });
}
