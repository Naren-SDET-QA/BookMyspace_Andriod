import 'package:bookmyspace/features/reviews/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Review parses numeric ratings and owner replies', () {
    final review = Review.fromJson({
      'id': 'r1',
      'venue_id': 'v1',
      'user_id': 'u1',
      'rating': 4.0,
      'title': 'Nice',
      'body': 'Good lighting',
      'is_verified': true,
      'owner_reply': 'Thank you',
      'created_at': '2026-09-01T00:00:00Z',
    });
    expect(review.rating, 4);
    expect(review.isVerified, isTrue);
    expect(review.ownerReply, 'Thank you');
    expect(review.title, 'Nice');
  });
}
