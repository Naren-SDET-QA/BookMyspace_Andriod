import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../home/presentation/discovery_location.dart';
import '../../location/presentation/location_providers.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';
import '../domain/room_inventory.dart';
import '../domain/room_inventory_repository.dart';
import '../infrastructure/supabase_room_inventory_repository.dart';
import '../infrastructure/supabase_venue_repository.dart';
import '../infrastructure/caching_venue_repository.dart';
import '../../../core/offline/offline_providers.dart';
import '../domain/media_repository.dart';
import '../infrastructure/supabase_media_repository.dart';
import 'category_configuration_providers.dart';

/// Venue repository instance.
///
/// Watches [currentUserProvider] (not the Supabase client's snapshot
/// `currentUser`) so this provider -- and the [CachingVenueRepository.
/// cacheScope] baked into it -- rebuilds on every auth transition
/// (sign-in, sign-out, and switching between accounts) without
/// requiring an app restart. Reading the client snapshot directly would
/// freeze the offline favorites cache scope to whichever user was
/// signed in when this provider was first built, letting a later
/// account read or overwrite the previous account's cached favorites.
final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  return CachingVenueRepository(
    SupabaseVenueRepository(client),
    ref.watch(offlineCacheProvider),
    cacheScope: userId,
  );
});

/// Categories provider (active categories for discovery/browsing).
///
/// Supabase Realtime keeps customer discovery in sync with admin changes.
final venueCategoriesProvider = StreamProvider<List<VenueCategory>>((ref) {
  return ref
      .watch(venueRepositoryProvider)
      .categoryStream(activeOnly: true)
      .map(
        (categories) => categories
            .where((category) => category.listingTemplate.isPublished)
            .toList(growable: false),
      );
});

/// All categories provider for management screens (including inactive ones).
final allVenueCategoriesProvider = StreamProvider<List<VenueCategory>>((ref) {
  return ref.watch(venueRepositoryProvider).categoryStream(activeOnly: false);
});

/// Active subsections for customer catalogue surfaces.
final venueSubsectionsProvider = StreamProvider.autoDispose
    .family<List<VenueSubsection>, String>((ref, categoryId) {
  return ref
      .watch(venueRepositoryProvider)
      .subsectionStream(categoryId, activeOnly: true);
});

/// All subsections for management screens, including disabled rows.
final allVenueSubsectionsProvider = StreamProvider.autoDispose
    .family<List<VenueSubsection>, String>((ref, categoryId) {
  return ref
      .watch(venueRepositoryProvider)
      .subsectionStream(categoryId, activeOnly: false);
});

/// Active subsection catalogue for customer discovery surfaces.
final venueSubsectionsCatalogProvider =
    StreamProvider<List<VenueSubsection>>((ref) {
  return ref.watch(venueRepositoryProvider).subsectionCatalogStream();
});

/// Complete subsection catalogue for management dashboards and aggregate
/// counts. Customer surfaces must continue using the active-only provider.
final allVenueSubsectionsCatalogProvider =
    StreamProvider<List<VenueSubsection>>((ref) {
  return ref
      .watch(venueRepositoryProvider)
      .subsectionCatalogStream(activeOnly: false);
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
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return SupabaseMediaRepository(ref.watch(supabaseProvider));
});

final roomInventoryRepositoryProvider = Provider<RoomInventoryRepository>((
  ref,
) {
  return SupabaseRoomInventoryRepository(ref.watch(supabaseProvider));
});

final hotelRoomTypesProvider = FutureProvider.autoDispose
    .family<List<HotelRoomType>, String>((ref, venueId) {
      return ref
          .watch(roomInventoryRepositoryProvider)
          .roomTypesForVenue(venueId);
    });

/// Category-scoped Home data. This provider is created and queried only when
/// the corresponding module widget resolves it; Home must not use it for
/// disabled modules. The query remains bounded by the repository contract.
final moduleVenuesProvider = FutureProvider.autoDispose
    .family<List<Venue>, String>((ref, moduleId) async {
      final repository = ref.watch(venueRepositoryProvider);
      final configurations = await ref.watch(
        categoryConfigurationsProvider.future,
      );
      final matching = configurations
          .where(
            (configuration) =>
                configuration.id == moduleId ||
                configuration.slug == moduleId ||
                configuration.sectionId == moduleId,
          )
          .toList(growable: false);
      if (matching.isEmpty) return repository.popularVenues(limit: 10);

      final slugs = matching.map((configuration) => configuration.slug).toSet();
      final pages = await Future.wait(
        slugs.map(
          (slug) => repository.search(VenueSearchQuery(categorySlug: slug)),
        ),
      );
      final unique = <String, Venue>{
        for (final venue in pages.expand((page) => page)) venue.id: venue,
      };
      return unique.values.take(50).toList(growable: false);
    });


// ---------------------------------------------------------------------------
// release/v1.0 search/favorite providers. The main lineage uses the family
// [searchResultsProvider] and [favoriteVenueIdsProvider]; these keep the
// release screens (map, search v1, list cards) working unchanged.
// ---------------------------------------------------------------------------

/// Holds the current search query; drives [currentSearchResultsProvider].
final searchQueryProvider = StateProvider<VenueSearchQuery>((ref) {
  return const VenueSearchQuery();
});

/// Search results reacting to the current [searchQueryProvider].
final currentSearchResultsProvider = FutureProvider<List<Venue>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(venueRepositoryProvider).search(query);
});

/// Ids of venues favourited by the signed-in user.
final favoriteIdsProvider = favoriteVenueIdsProvider;

/// Toggles a venue in the user's favourites and invalidates the caches.
final toggleFavoriteProvider = FutureProvider.family<void, String>((
  ref,
  venueId,
) async {
  final repo = ref.watch(venueRepositoryProvider);
  final ids = await repo.favoriteIds();
  if (ids.contains(venueId)) {
    await repo.removeFavorite(venueId);
  } else {
    await repo.addFavorite(venueId);
  }
  ref.invalidate(favoriteVenueIdsProvider);
  ref.invalidate(favoritesProvider);
});
