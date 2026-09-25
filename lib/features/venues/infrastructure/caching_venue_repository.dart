import '../../../core/offline/offline_cache.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';
import '../domain/listing_template.dart';

/// Read-through cache around a live [VenueRepository].
///
/// Mutations and the live fetch path are unchanged. Cached snapshots are used
/// only when the inner repository fails for a connectivity reason.
class CachingVenueRepository implements VenueRepository {
  CachingVenueRepository(this._inner, this._cache, {this.cacheScope});

  final VenueRepository _inner;
  final OfflineCache _cache;
  final String? cacheScope;

  String get _favoritesKey => cacheScope == null || cacheScope!.isEmpty
      ? 'venues.favorites'
      : 'venues.favorites.$cacheScope';

  @override
  Future<List<VenueCategory>> categories({bool activeOnly = false}) =>
      _inner.categories(activeOnly: activeOnly);

  @override
  Future<List<Venue>> popularVenues({int limit = 10}) {
    return _cache.readThroughVenues(
      '${OfflineCache.popularKey}.$limit',
      () => _inner.popularVenues(limit: limit),
    );
  }

  @override
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  }) {
    return _cache.readThroughVenues(
      '${OfflineCache.nearbyKey}.$latitude,$longitude,$maxDistanceKm,$limit',
      () => _inner.nearbyVenues(
        latitude: latitude,
        longitude: longitude,
        maxDistanceKm: maxDistanceKm,
        limit: limit,
      ),
    );
  }

  @override
  Future<List<Venue>> search(VenueSearchQuery query) {
    return _cache.readThroughVenues(
      OfflineCache.searchKey(query),
      () => _inner.search(query),
    );
  }

  @override
  Future<Venue> venueById(String id) {
    return _cache.readThroughVenue(id, () => _inner.venueById(id));
  }

  @override
  Future<List<String>> favoriteIds() => _inner.favoriteIds();

  @override
  Future<List<Venue>> favorites() {
    return _cache.readThroughVenues(_favoritesKey, _inner.favorites);
  }

  @override
  Future<void> addFavorite(String venueId) => _inner.addFavorite(venueId);

  @override
  Future<void> removeFavorite(String venueId) => _inner.removeFavorite(venueId);

  // Delegates for BookingRepository/VenueRepository members added by the
  // main lineage (no offline caching for these yet).
  @override
  Future<VenueCategory> getCategory(String id) =>
      _inner.getCategory(id);

  @override
  Future<VenueCategory> addCategory({ required String name, required String slug, String? icon, String? parentSection, bool isActive = true, ListingTemplateConfig? listingConfig = null, }) =>
      _inner.addCategory(name: name, slug: slug, icon: icon, parentSection: parentSection, isActive: isActive, listingConfig: listingConfig);

  @override
  Future<VenueCategory> updateCategory(VenueCategory category) =>
      _inner.updateCategory(category);

  @override
  Future<void> setCategoryActive(String categoryId, bool isActive) =>
      _inner.setCategoryActive(categoryId, isActive);

  @override
  Stream<List<VenueCategory>> categoryStream({bool activeOnly = false}) =>
      _inner.categoryStream(activeOnly: activeOnly);

  @override
  Future<List<VenueSubsection>> subsections( String categoryId, { bool activeOnly = false, }) =>
      _inner.subsections(categoryId, activeOnly: activeOnly);

  @override
  Stream<List<VenueSubsection>> subsectionStream( String categoryId, { bool activeOnly = false, }) =>
      _inner.subsectionStream(categoryId, activeOnly: activeOnly);

  @override
  Stream<List<VenueSubsection>> subsectionCatalogStream({ bool activeOnly = true, }) =>
      _inner.subsectionCatalogStream(activeOnly: activeOnly);

  @override
  Future<VenueSubsection> addSubsection({ required String categoryId, required String name, required String slug, String? icon, String description = '', String? imageUrl, String? imagePath, bool isActive = true, int displayOrder = 0, List<String> supportedLanguages = const ['en'], Map<String, String> nameTranslations = const {}, Map<String, String> descriptionTranslations = const {}, }) =>
      _inner.addSubsection(categoryId: categoryId, name: name, slug: slug, icon: icon, description: description, imageUrl: imageUrl, imagePath: imagePath, isActive: isActive, displayOrder: displayOrder, supportedLanguages: supportedLanguages, nameTranslations: nameTranslations, descriptionTranslations: descriptionTranslations);

  @override
  Future<VenueSubsection> updateSubsection(VenueSubsection subsection) =>
      _inner.updateSubsection(subsection);

  @override
  Future<void> deleteCategory(String categoryId) =>
      _inner.deleteCategory(categoryId);

  @override
  Future<void> deleteSubsection(String subsectionId) =>
      _inner.deleteSubsection(subsectionId);

  @override
  Future<void> reorderCategories(List<String> categoryIds) =>
      _inner.reorderCategories(categoryIds);

  @override
  Future<void> reorderSubsections( String categoryId, List<String> subsectionIds, ) =>
      _inner.reorderSubsections(categoryId, subsectionIds);

  @override
  Future<VenueCategory> uploadCategoryImage({ required VenueCategory category, required List<int> bytes, required String extension, }) =>
      _inner.uploadCategoryImage(category: category, bytes: bytes, extension: extension);

  @override
  Future<void> removeCategoryImage(VenueCategory category) =>
      _inner.removeCategoryImage(category);

  @override
  Future<VenueSubsection> uploadSubsectionImage({ required VenueSubsection subsection, required List<int> bytes, required String extension, }) =>
      _inner.uploadSubsectionImage(subsection: subsection, bytes: bytes, extension: extension);

  @override
  Future<void> removeSubsectionImage(VenueSubsection subsection) =>
      _inner.removeSubsectionImage(subsection);

  @override
  Future<List<String>> listedCities() =>
      _inner.listedCities();
}
