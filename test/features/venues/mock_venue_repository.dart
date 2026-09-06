import '../../venues/domain/venue.dart';
import '../../venues/domain/venue_repository.dart';

class MockVenueRepository implements VenueRepository {
  bool failRequests = false;
  final List<String> _favs = [];

  final List<Venue> _mockVenues = [
    const Venue(
      id: 'v1',
      name: 'Grand Function Palace',
      slug: 'grand-function-palace',
      city: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.3850,
      longitude: 78.4867,
      capacity: 600,
      pricingBaseAmount: 45000,
      price: 45000,
      avgRating: 4.8,
      ratingCount: 150,
      isVerified: true,
      category: VenueCategory(id: 'c1', slug: 'function_hall', name: 'Function Hall'),
    ),
    const Venue(
      id: 'v2',
      name: 'Executive Boardroom',
      slug: 'executive-boardroom',
      city: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.4400,
      longitude: 78.3489,
      capacity: 30,
      pricingBaseAmount: 5000,
      price: 5000,
      avgRating: 4.6,
      ratingCount: 85,
      isVerified: true,
      category: VenueCategory(id: 'c2', slug: 'meeting_room', name: 'Meeting Room'),
    ),
    const Venue(
      id: 'v3',
      name: 'Skyline Community Center',
      slug: 'skyline-community-center',
      city: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.4123,
      longitude: 78.4080,
      capacity: 250,
      pricingBaseAmount: 20000,
      price: 20000,
      avgRating: 4.9,
      ratingCount: 214,
      isVerified: true,
      category: VenueCategory(id: 'c1', slug: 'function_hall', name: 'Function Hall'),
    ),
  ];

  @override
  Future<List<VenueCategory>> categories() async {
    if (failRequests) throw Exception('Network failure');
    return const [
      VenueCategory(id: 'c1', slug: 'function_hall', name: 'Function Hall'),
      VenueCategory(id: 'c2', slug: 'meeting_room', name: 'Meeting Room'),
      VenueCategory(id: 'c3', slug: 'party_hall', name: 'Party Hall'),
    ];
  }

  @override
  Future<List<Venue>> popularVenues({int limit = 10}) async {
    if (failRequests) throw Exception('Network failure');
    final list = [..._mockVenues]..sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
    return list.take(limit).toList();
  }

  @override
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  }) async {
    if (failRequests) throw Exception('Network failure');
    return _mockVenues.take(limit).toList();
  }

  @override
  Future<List<Venue>> search(VenueSearchQuery query) async {
    if (failRequests) throw Exception('Network failure');
    var filtered = _mockVenues.where((v) {
      if (query.categorySlug != null && v.category?.slug != query.categorySlug) {
        return false;
      }
      if (query.query.isNotEmpty &&
          !v.name.toLowerCase().contains(query.query.toLowerCase()) &&
          !v.city.toLowerCase().contains(query.query.toLowerCase())) {
        return false;
      }
      if (query.minPrice != null && v.price < query.minPrice!) {
        return false;
      }
      if (query.maxPrice != null && v.price > query.maxPrice!) {
        return false;
      }
      return true;
    }).toList();

    switch (query.sortBy) {
      case VenueSortBy.priceAsc:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case VenueSortBy.priceDesc:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case VenueSortBy.rating:
        filtered.sort((a, b) => b.avgRating.compareTo(a.avgRating));
        break;
      default:
        filtered.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
        break;
    }

    return filtered;
  }

  @override
  Future<Venue> venueById(String id) async {
    if (failRequests) throw Exception('Network failure');
    return _mockVenues.firstWhere((v) => v.id == id);
  }

  @override
  Future<List<String>> favoriteIds() async {
    if (failRequests) throw Exception('Network failure');
    return [..._favs];
  }

  @override
  Future<List<Venue>> favorites() async {
    if (failRequests) throw Exception('Network failure');
    return _mockVenues.where((v) => _favs.contains(v.id)).toList();
  }

  @override
  Future<void> addFavorite(String venueId) async {
    if (failRequests) throw Exception('Network failure');
    if (!_favs.contains(venueId)) _favs.add(venueId);
  }

  @override
  Future<void> removeFavorite(String venueId) async {
    if (failRequests) throw Exception('Network failure');
    _favs.remove(venueId);
  }
}
