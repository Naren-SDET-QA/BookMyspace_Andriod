import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../home/presentation/discovery_location.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';
import '../infrastructure/supabase_venue_repository.dart';

/// Venue repository provider backed by SupabaseClient.
final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseVenueRepository(client);
});

/// Categories provider (active categories for discovery/browsing).
final venueCategoriesProvider = FutureProvider<List<VenueCategory>>((ref) {
  return ref.watch(venueRepositoryProvider).categories(activeOnly: true);
});

/// All categories provider for management screens (including inactive ones).
final allVenueCategoriesProvider = FutureProvider<List<VenueCategory>>((ref) {
  return ref.watch(venueRepositoryProvider).categories(activeOnly: false);
});

/// Popular venues provider.
final popularVenuesProvider = FutureProvider<List<Venue>>((ref) {
  return ref.watch(venueRepositoryProvider).popularVenues();
});

/// Distinct cities from readable venue listings.
final listedVenueCitiesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(venueRepositoryProvider).listedCities();
});

/// Nearby venues. Coordinates must come from a real user-selected location;
/// this provider does not invent a city centroid.
final nearbyVenuesProvider = FutureProvider<List<Venue>>((ref) async {
  final location = ref.watch(discoveryLocationProvider);
  if (!location.hasCoordinates) return const <Venue>[];
  return ref.watch(venueRepositoryProvider).nearbyVenues(
        latitude: location.latitude!,
        longitude: location.longitude!,
        maxDistanceKm: location.radiusKm.toDouble(),
      );
});

/// Search results for an explicit [VenueSearchQuery].
///
/// The query must come from route parameters or from a user action in the
/// current screen. Screens must not write a shared search provider during
/// widget construction (`initState` / `build`).
final searchResultsProvider =
    FutureProvider.autoDispose.family<List<Venue>, VenueSearchQuery>((
  ref,
  query,
) {
  return ref.watch(venueRepositoryProvider).search(query);
});

/// Venue details provider by venue ID.
final venueDetailsProvider = FutureProvider.autoDispose.family<Venue, String>((
  ref,
  venueId,
) {
  return ref.watch(venueRepositoryProvider).venueById(venueId);
});

/// Canonical favorite-id list. All per-venue hearts derive from this.
final favoriteVenueIdsProvider = FutureProvider<List<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(venueRepositoryProvider).favoriteIds();
});

/// Favorite status for a venue, derived from [favoriteVenueIdsProvider].
final isFavoriteProvider =
    Provider.autoDispose.family<AsyncValue<bool>, String>((ref, venueId) {
  return ref.watch(favoriteVenueIdsProvider).whenData(
        (ids) => ids.contains(venueId),
      );
});

/// User-action helper for favorite toggles. Do not watch from build().
class FavoriteController {
  FavoriteController(this._ref);

  final Ref _ref;

  Future<void> toggle(String venueId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      throw const AuthException('Sign in to save venues.');
    }
    final repo = _ref.read(venueRepositoryProvider);
    final ids = await repo.favoriteIds();
    if (ids.contains(venueId)) {
      await repo.removeFavorite(venueId);
    } else {
      await repo.addFavorite(venueId);
    }
    _ref.invalidate(favoriteVenueIdsProvider);
    _ref.invalidate(savedVenuesProvider);
  }
}

final favoriteControllerProvider = Provider<FavoriteController>((ref) {
  return FavoriteController(ref);
});

/// Saved venues list provider.
final savedVenuesProvider = FutureProvider<List<Venue>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(venueRepositoryProvider).favorites();
});

final favoritesProvider = savedVenuesProvider;
