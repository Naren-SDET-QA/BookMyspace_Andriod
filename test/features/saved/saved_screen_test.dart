import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/modules/presentation/module_providers.dart';
import 'package:bookmyspace/features/saved/domain/saved_venue_filter.dart';
import 'package:bookmyspace/features/saved/presentation/screens/saved_screen.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../venues/mock_venue_repository.dart';

const _hall = VenueCategory(id: 'c1', slug: 'hall', name: 'Function Hall');
const _meeting = VenueCategory(id: 'c2', slug: 'meet', name: 'Meeting Room');

const _venues = [
  Venue(
    id: 'v1',
    name: 'Sunrise Hall',
    city: 'Hyderabad',
    latitude: 0,
    longitude: 0,
    category: _hall,
  ),
  Venue(
    id: 'v2',
    name: 'Work Nest',
    city: 'Pune',
    latitude: 0,
    longitude: 0,
    category: _meeting,
  ),
  Venue(
    id: 'v3',
    name: 'Lotus Banquet',
    city: 'Pune',
    latitude: 0,
    longitude: 0,
    category: _hall,
  ),
];

void main() {
  group('SavedVenueFilter', () {
    test('derives distinct categories in order', () {
      final cats = SavedVenueFilter.categoriesOf(_venues);
      expect(cats.map((c) => c.name), ['Function Hall', 'Meeting Room']);
    });

    test('filters by name/city and category', () {
      expect(SavedVenueFilter.apply(_venues, query: 'pune').map((v) => v.id), [
        'v2',
        'v3',
      ]);
      expect(SavedVenueFilter.apply(_venues, query: 'LOTUS').single.id, 'v3');
      expect(
        SavedVenueFilter.apply(_venues, categoryKey: 'c1').map((v) => v.id),
        ['v1', 'v3'],
      );
      expect(
        SavedVenueFilter.apply(
          _venues,
          query: 'pune',
          categoryKey: 'c1',
        ).single.id,
        'v3',
      );
      expect(SavedVenueFilter.apply(_venues, query: 'zzz'), isEmpty);
    });
  });

  testWidgets('saved screen search, category chips and reset', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          moduleEnabledProvider.overrideWith((ref, id) => true),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          savedVenuesProvider.overrideWith((ref) async => _venues),
        ],
        child: const MaterialApp(
          home: SavedScreen(),
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

    expect(find.byKey(const Key('saved-category-c1')), findsOneWidget);
    expect(find.byKey(const Key('saved-category-c2')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('saved-category-c2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved-category-c2')));
    await tester.pumpAndSettle();
    expect(find.text('Work Nest'), findsOneWidget);
    expect(find.text('Sunrise Hall'), findsNothing);

    await tester.enterText(find.byKey(const Key('saved-search')), 'Hyderabad');
    await tester.pumpAndSettle();
    expect(find.text('No saved venues match'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saved-reset-filters')));
    await tester.pumpAndSettle();
    expect(find.text('No saved venues match'), findsNothing);
    expect(find.text('Sunrise Hall'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
