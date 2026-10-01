import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../venues/presentation/venue_providers.dart';
import '../domain/review.dart';
import '../infrastructure/supabase_review_repository.dart';

/// Review repository backed by Supabase.
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseReviewRepository(client);
});

/// Public reviews for a venue.
final venueReviewsProvider =
    FutureProvider.autoDispose.family<List<Review>, String>((ref, venueId) {
  return ref.watch(reviewRepositoryProvider).venueReviews(venueId);
});

/// Signed-in user's review for a venue, if any.
final myReviewProvider =
    FutureProvider.autoDispose.family<Review?, String>((ref, venueId) {
  ref.watch(currentUserProvider);
  return ref.watch(reviewRepositoryProvider).myReviewForVenue(venueId);
});

/// User-action helper for creating a review. Never watch this from build.
class ReviewController {
  ReviewController(this._ref);

  final Ref _ref;

  Future<Review> submit({
    required String venueId,
    required int rating,
    String? title,
    String? body,
  }) async {
    final review = await _ref.read(reviewRepositoryProvider).submitReview(
          venueId: venueId,
          rating: rating,
          title: title,
          body: body,
        );
    _ref.invalidate(venueReviewsProvider(venueId));
    _ref.invalidate(myReviewProvider(venueId));
    _ref.invalidate(venueDetailsProvider(venueId));
    return review;
  }
}

final reviewControllerProvider = Provider<ReviewController>((ref) {
  return ReviewController(ref);
});
