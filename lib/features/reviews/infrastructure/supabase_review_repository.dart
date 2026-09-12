import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as errors;
import '../domain/review.dart';

/// Supabase-backed [ReviewRepository] against the live `public.reviews` table.
class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<Review>> venueReviews(String venueId) async {
    try {
      final rows = await _client
          .from('reviews')
          .select('*')
          .eq('venue_id', venueId)
          .order('created_at', ascending: false);
      final reviews = rows.map(Review.fromJson).toList();
      return _withReviewerNames(reviews);
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<Review?> myReviewForVenue(String venueId) async {
    if (_userId == null) return null;
    try {
      final rows = await _client
          .from('reviews')
          .select('*')
          .eq('venue_id', venueId)
          .eq('user_id', _userId!)
          .limit(1);
      if (rows.isEmpty) return null;
      final named = await _withReviewerNames([Review.fromJson(rows.first)]);
      return named.first;
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<Review> submitReview({
    required String venueId,
    required int rating,
    String? title,
    String? body,
    String? bookingId,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw const errors.AuthException('Sign in to write a review.');
    }
    try {
      final payload = <String, dynamic>{
        'venue_id': venueId,
        'user_id': userId,
        'rating': rating,
        'title': title,
        'body': body,
      };
      if (bookingId != null && bookingId.isNotEmpty) {
        payload['booking_id'] = bookingId;
      }
      final rows =
          await _client.from('reviews').insert(payload).select().limit(1);
      return Review.fromJson(rows.first);
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<Review> updateReview({
    required String reviewId,
    int? rating,
    String? title,
    String? body,
  }) async {
    try {
      final update = <String, dynamic>{};
      if (rating != null) update['rating'] = rating;
      if (title != null) update['title'] = title;
      if (body != null) update['body'] = body;

      final rows = await _client
          .from('reviews')
          .update(update)
          .eq('id', reviewId)
          .select()
          .limit(1);
      return Review.fromJson(rows.first);
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    try {
      await _client.from('reviews').delete().eq('id', reviewId);
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<double> averageRating(String venueId) async {
    try {
      final rows = await _client
          .from('reviews')
          .select('rating')
          .eq('venue_id', venueId);
      if (rows.isEmpty) return 0;
      final total = rows.fold<int>(
        0,
        (sum, r) => sum + ((r['rating'] as num?)?.toInt() ?? 0),
      );
      return total / rows.length;
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  Future<List<Review>> _withReviewerNames(List<Review> reviews) async {
    final ids = reviews
        .map((r) => r.userId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return reviews;
    try {
      final profiles = await _client
          .from('profiles')
          .select('id, full_name')
          .inFilter('id', ids);
      final names = <String, String>{};
      for (final row in profiles) {
        final id = row['id'] as String?;
        final name = row['full_name'] as String?;
        if (id != null && name != null && name.trim().isNotEmpty) {
          names[id] = name.trim();
        }
      }
      if (names.isEmpty) return reviews;
      return reviews
          .map((review) => review.copyWith(userName: names[review.userId]))
          .toList();
    } catch (_) {
      return reviews;
    }
  }
}
