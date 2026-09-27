import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/settings_controller.dart';
import '../../venues/domain/venue.dart';

/// A venue the customer opened recently, kept small on purpose: enough to
/// render a Home card and link back to the venue without a network call.
@immutable
class RecentlyViewedVenue {
  const RecentlyViewedVenue({
    required this.id,
    required this.name,
    this.city = '',
    this.imageUrl = '',
    this.rating = 0,
    this.ratingCount = 0,
  });

  factory RecentlyViewedVenue.fromVenue(Venue venue) => RecentlyViewedVenue(
    id: venue.id,
    name: venue.name,
    city: venue.city,
    imageUrl: venue.coverOrSampleImageUrl,
    rating: venue.avgRating,
    ratingCount: venue.ratingCount,
  );

  factory RecentlyViewedVenue.fromJson(Map<String, dynamic> json) =>
      RecentlyViewedVenue(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        imageUrl: json['image']?.toString() ?? '',
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final String city;
  final String imageUrl;
  final double rating;
  final int ratingCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'image': imageUrl,
    'rating': rating,
    'rating_count': ratingCount,
  };
}

/// Venues this device opened most recently, newest first.
///
/// Stored locally (per device, per browser) through [Preferences]; nothing is
/// sent to the backend. Storage failures degrade to an empty list rather than
/// surfacing errors on Home.
class RecentlyViewedNotifier extends AsyncNotifier<List<RecentlyViewedVenue>> {
  static const storageKey = 'recently_viewed_venues_v1';
  static const maxEntries = 12;

  @override
  Future<List<RecentlyViewedVenue>> build() async {
    try {
      final raw = await ref.read(preferencesProvider).read(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RecentlyViewedVenue.fromJson)
          .where((v) => v.id.isNotEmpty && v.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Moves [venue] to the front of the list.
  Future<void> record(Venue venue) async {
    final current =
        state.valueOrNull ??
        await future.catchError((_) => const <RecentlyViewedVenue>[]);
    final next = [
      RecentlyViewedVenue.fromVenue(venue),
      ...current.where((v) => v.id != venue.id),
    ].take(maxEntries).toList(growable: false);
    state = AsyncData(next);
    try {
      await ref
          .read(preferencesProvider)
          .write(storageKey, jsonEncode(next.map((v) => v.toJson()).toList()));
    } catch (_) {
      // Keep the in-memory list; persistence is best-effort.
    }
  }
}

final recentlyViewedProvider =
    AsyncNotifierProvider<RecentlyViewedNotifier, List<RecentlyViewedVenue>>(
      RecentlyViewedNotifier.new,
    );
