import 'venue.dart';

/// Contract for venue repository.
abstract class VenueRepository {
  /// Fetches venue categories. Pass [activeOnly] to filter active ones.
  Future<List<VenueCategory>> categories({bool activeOnly = false});

  /// Adds a new category.
  Future<VenueCategory> addCategory({
    required String name,
    required String slug,
    String? icon,
    String? parentSection,
    bool isActive = true,
  });

  /// Updates an existing category.
  Future<VenueCategory> updateCategory(VenueCategory category);

  /// Sets category active status.
  Future<void> setCategoryActive(String categoryId, bool isActive);

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
