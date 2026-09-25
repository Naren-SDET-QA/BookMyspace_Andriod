import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/review_providers.dart';
import 'package:bookmyspace/features/reviews/presentation/widgets/venue_reviews_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import 'mock_review_repository.dart';

Widget _app(MockReviewRepository repo) {
  return ProviderScope(
    overrides: [
      reviewRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        ),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: VenueReviewsSection(
            venueId: 'v1',
            avgRating: 4.3,
            ratingCount: 4,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('breakdown shows score, distribution and star filter chips',
      (tester) async {
    final repo = MockReviewRepository(reviews: [
      MockReviewRepository.sample(id: 'r1', rating: 5, userName: 'Asha'),
      MockReviewRepository.sample(id: 'r2', rating: 5, userName: 'Ravi'),
      MockReviewRepository.sample(id: 'r3', rating: 4, userName: 'Meena'),
      MockReviewRepository.sample(id: 'r4', rating: 3, userName: 'John'),
    ]);

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Ratings & reviews'), findsOneWidget);
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('out of 5.0'), findsOneWidget);
    expect(find.text('4 verified reviews'), findsOneWidget);
    expect(find.text('All (4)'), findsOneWidget);
    expect(find.text('5★ (2)'), findsOneWidget);
    expect(find.text('3★ (1)'), findsOneWidget);
    expect(find.text('1★ (0)'), findsOneWidget);
    // All four reviews render by default.
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);
  });

  testWidgets('star chips filter the review list', (tester) async {
    final repo = MockReviewRepository(reviews: [
      MockReviewRepository.sample(id: 'r1', rating: 5, userName: 'Asha'),
      MockReviewRepository.sample(id: 'r4', rating: 3, userName: 'John'),
    ]);

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3★ (1)'));
    await tester.pumpAndSettle();

    expect(find.text('John'), findsOneWidget);
    expect(find.text('Asha'), findsNothing);

    // Switch to a star with no reviews → safe fallback message.
    await tester.tap(find.text('2★ (0)'));
    await tester.pumpAndSettle();

    expect(find.text('No 2★ reviews found.'), findsOneWidget);
    expect(find.text('John'), findsNothing);

    // Back to all.
    await tester.tap(find.text('All (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);
  });

  testWidgets('empty venue reviews still show the safe empty state',
      (tester) async {
    await tester.pumpWidget(_app(MockReviewRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet. Be the first to review this venue.'),
        findsOneWidget);
    expect(find.text('Ratings & reviews'), findsNothing);
  });
}
