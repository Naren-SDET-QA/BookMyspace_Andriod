import 'package:bookmyspace/features/reviews/domain/review.dart';

class MockReviewRepository implements ReviewRepository {
  MockReviewRepository({List<Review>? reviews}) : reviews = reviews ?? [];

  List<Review> reviews;
  bool failList = false;
  bool failSubmit = false;
  Review? submitted;

  static Review sample({
    String id = 'r1',
    String venueId = 'v1',
    String userId = 'u1',
    int rating = 5,
    String? title = 'Great hall',
    String? body = 'Spacious and clean.',
    String? userName = 'Asha',
  }) {
    return Review(
      id: id,
      venueId: venueId,
      userId: userId,
      rating: rating,
      title: title,
      body: body,
      userName: userName,
      createdAt: DateTime(2026, 9, 1),
    );
  }

  @override
  Future<double> averageRating(String venueId) async {
    final items = reviews.where((r) => r.venueId == venueId);
    if (items.isEmpty) return 0;
    return items.map((r) => r.rating).reduce((a, b) => a + b) / items.length;
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    reviews = reviews.where((r) => r.id != reviewId).toList();
  }

  @override
  Future<Review?> myReviewForVenue(String venueId) async {
    for (final review in reviews) {
      if (review.venueId == venueId && review.userId == 'u1') return review;
    }
    return null;
  }

  @override
  Future<Review> submitReview({
    required String venueId,
    required int rating,
    String? title,
    String? body,
    String? bookingId,
  }) async {
    if (failSubmit) throw Exception('submit failed');
    submitted = Review(
      id: 'new',
      venueId: venueId,
      userId: 'u1',
      rating: rating,
      title: title,
      body: body,
      bookingId: bookingId,
      userName: 'Asha',
    );
    reviews = [...reviews, submitted!];
    return submitted!;
  }

  @override
  Future<Review> updateReview({
    required String reviewId,
    int? rating,
    String? title,
    String? body,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Review>> venueReviews(String venueId) async {
    if (failList) throw Exception('reviews failed');
    return reviews.where((r) => r.venueId == venueId).toList();
  }
}
