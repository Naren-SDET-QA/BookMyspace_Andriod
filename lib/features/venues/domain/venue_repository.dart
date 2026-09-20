import 'venue.dart';

/// Contract for venue repository.
abstract class VenueRepository {
  /// Fetches venue categories. Pass [activeOnly] to filter active ones.
  Future<List<VenueCategory>> categories({bool activeOnly = false});

  /// Gets a single venue category by ID with full details including the
  /// resolved listing template. Used by admin editing surfaces.
  Future<VenueCategory> getCategory(String id);

  /// Adds a new category.
  Future<VenueCategory> addCategory({
    required String name,
    required String slug,
    String? icon,
    String? parentSection,
    bool isActive = true,
    ListingTemplateConfig? listingConfig = null,
  });

  /// Updates an existing category.
  Future<VenueCategory> updateCategory(VenueCategory category);

  /// Sets category active status.
  Future<void> setCategoryActive(String categoryId, bool isActive);

  /// Emits the catalogue whenever Supabase Realtime reports a change.
  Stream<List<VenueCategory>> categoryStream({bool activeOnly = false});

  /// Fetches the subsections belonging to a category.
  Future<List<VenueSubsection>> subsections(
    String categoryId, {
    bool activeOnly = false,
  });

  /// Emits the subsections belonging to a category in display order.
  Stream<List<VenueSubsection>> subsectionStream(
    String categoryId, {
    bool activeOnly = false,
  });

  /// Emits all active catalogue subsections for customer discovery surfaces.
  Stream<List<VenueSubsection>> subsectionCatalogStream({
    bool activeOnly = true,
  });

  /// Creates a second-level category.
  Future<VenueSubsection> addSubsection({
    required String categoryId,
    required String name,
    required String slug,
    String? icon,
    String description = '',
    String? imageUrl,
    String? imagePath,
    bool isActive = true,
    int displayOrder = 0,
    List<String> supportedLanguages = const ['en'],
    Map<String, String> nameTranslations = const {},
    Map<String, String> descriptionTranslations = const {},
  });

  /// Updates a second-level category.
  Future<VenueSubsection> updateSubsection(VenueSubsection subsection);

  /// Deletes a category and its subsections after UI confirmation.
  Future<void> deleteCategory(String categoryId);

  /// Deletes a subsection after UI confirmation.
  Future<void> deleteSubsection(String subsectionId);

  /// Atomically persists category order.
  Future<void> reorderCategories(List<String> categoryIds);

  /// Atomically persists subsection order within a category.
  Future<void> reorderSubsections(
    String categoryId,
    List<String> subsectionIds,
  );

  /// Uploads a category image into the shared media bucket.
  Future<VenueCategory> uploadCategoryImage({
    required VenueCategory category,
    required List<int> bytes,
    required String extension,
  });

  /// Removes category image metadata and its storage object.
  Future<void> removeCategoryImage(VenueCategory category);

  /// Uploads a subsection image into the shared media bucket.
  Future<VenueSubsection> uploadSubsectionImage({
    required VenueSubsection subsection,
    required List<int> bytes,
    required String extension,
  });

  /// Removes subsection image metadata and its storage object.
  Future<void> removeSubsectionImage(VenueSubsection subsection);

  /// Distinct venue cities from listings the caller can read.
  Future<List<String>> listedCities();

  /// Fetches popular venues.
  Future<List<Venue>> popularVenues({int limit = 10});

  /// Fetches venues near given coordinates.
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  });

  /// Search venues by query and filters.
  Future<List<Venue>> search(VenueSearchQuery query);

  /// Get single venue by ID with full details.
  Future<Venue> venueById(String id);

  /// Get list of favorite venue IDs for user.
  Future<List<String>> favoriteIds();

  /// Get all favorited venues for user.
  Future<List<Venue>> favorites();

  /// Add venue to favorites.
  Future<void> addFavorite(String venueId);

  /// Remove venue from favorites.
  Future<void> removeFavorite(String venueId);
}
