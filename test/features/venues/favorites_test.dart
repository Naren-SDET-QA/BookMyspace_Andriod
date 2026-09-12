import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:bookmyspace/features/venues/presentation/widgets/venue_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_venue_repository.dart';

const _venue = Venue(
  id: 'v1',
  name: 'Sunrise Function Hall',
  city: 'Hyderabad',
  latitude: 17.3850,
  longitude: 78.4867,
  price: 45000,
);

Widget _cardApp({
  required MockVenueRepository venues,
  AuthUser? user,
}) {
  return ProviderScope(
    overrides: [
      venueRepositoryProvider.overrideWithValue(venues),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: user),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: VenueCard(venue: _venue)),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, __) => const Scaffold(body: Text('Login')),
          ),
          GoRoute(
            path: AppRoutes.venueDetails,
            builder: (_, __) => const Scaffold(body: Text('Details')),
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
  );
}

void main() {
  testWidgets('favorite persists across rebuilds and can be removed',
      (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(
      _cardApp(
        venues: repo,
        user: const AuthUser(id: 'u1', email: 'a@b.com'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_outline_rounded));
    await tester.pumpAndSettle();
    expect(await repo.favoriteIds(), ['v1']);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.pumpWidget(
      _cardApp(
        venues: repo,
        user: const AuthUser(id: 'u1', email: 'a@b.com'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pumpAndSettle();
    expect(await repo.favoriteIds(), isEmpty);
    expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget);
  });

  testWidgets('unauthenticated favorite tap opens login', (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_cardApp(venues: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    expect(await repo.favoriteIds(), isEmpty);
  });
}
