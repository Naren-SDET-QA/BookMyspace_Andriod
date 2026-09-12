import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/widgets/venue_reviews_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_review_repository.dart';

Widget _app(MockReviewRepository reviews, {AuthUser? user}) {
  return ProviderScope(
    overrides: [
      reviewRepositoryProvider.overrideWithValue(reviews),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(initialUser: user),
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
      home: Scaffold(body: VenueReviewsSection(venueId: 'v1')),
    ),
  );
}

void main() {
  testWidgets('shows empty reviews state', (tester) async {
    await tester.pumpWidget(_app(MockReviewRepository()));
    await tester.pumpAndSettle();
    expect(find.textContaining('No reviews yet'), findsOneWidget);
  });

  testWidgets('renders review data', (tester) async {
    await tester.pumpWidget(
      _app(MockReviewRepository(reviews: [MockReviewRepository.sample()])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Great hall'), findsOneWidget);
    expect(find.text('Spacious and clean.'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
  });

  testWidgets('shows error and retries', (tester) async {
    final repo = MockReviewRepository()..failList = true;
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);

    repo.failList = false;
    repo.reviews = [MockReviewRepository.sample()];
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Great hall'), findsOneWidget);
  });

  testWidgets('signed-out users are asked to sign in', (tester) async {
    await tester.pumpWidget(_app(MockReviewRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to review'), findsOneWidget);
  });

  testWidgets('signed-in users can open the write sheet', (tester) async {
    await tester.pumpWidget(
      _app(
        MockReviewRepository(),
        user: const AuthUser(id: 'u1', email: 'a@b.com'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();
    expect(find.text('Submit review'), findsOneWidget);
  });
}
