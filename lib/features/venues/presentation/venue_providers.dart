import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';
import '../infrastructure/supabase_venue_repository.dart';

/// Venue repository provider backed by SupabaseClient.
final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseVenueRepository(client);
});

/// Categories provider.
final venueCategoriesProvider = FutureProvider<List<VenueCategory>>((ref) {
  return ref.watch(venueRepositoryProvider).categories();
});

/// Popular venues provider.
final popularVenuesProvider = FutureProvider<List<Venue>>((ref) {
  return ref.watch(venueRepositoryProvider).popularVenues();
});

/// Nearby venues provider with default or location-based coords.
final nearbyVenuesProvider = FutureProvider<List<Venue>>((ref) {
  return ref.watch(venueRepositoryProvider).nearbyVenues(
    latitude: 17.3850,
    longitude: 78.4867,
    maxDistanceKm: 25,
  );
});

/// Search query state provider.
final searchQueryProvider = StateProvider<VenueSearchQuery>((ref) {
  return const VenueSearchQuery();
});

/// Search results provider driven by searchQueryProvider.
final searchResultsProvider = FutureProvider<List<Venue>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(venueRepositoryProvider).search(query);
});

/// Venue details provider by venue ID.
final venueDetailsProvider = FutureProvider.autoDispose.family<Venue, String>((
  ref,
  venueId,
) {
  return ref.watch(venueRepositoryProvider).venueById(venueId);
});

/// Favorite IDs provider.
final favoriteVenueIdsProvider = FutureProvider<List<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(venueRepositoryProvider).favoriteIds();
});

/// Favorite status for a specific venue.
final isFavoriteProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  venueId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final ids = await ref.watch(venueRepositoryProvider).favoriteIds();
  return ids.contains(venueId);
});

/// Toggle favorite action.
final toggleFavoriteProvider = FutureProvider.autoDispose.family<void, String>((
  ref,
  venueId,
) async {
  final repo = ref.watch(venueRepositoryProvider);
  final isFav = await repo.favoriteIds();
  if (isFav.contains(venueId)) {
    await repo.removeFavorite(venueId);
  } else {
    await repo.addFavorite(venueId);
  }
  ref.invalidate(favoriteVenueIdsProvider);
  ref.invalidate(isFavoriteProvider(venueId));
});

/// Saved venues list provider.
final savedVenuesProvider = FutureProvider<List<Venue>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(venueRepositoryProvider).favorites();
});
