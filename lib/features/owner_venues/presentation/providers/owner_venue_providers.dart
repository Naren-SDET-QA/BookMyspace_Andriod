import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../domain/owner_venue_repository.dart';
import '../../infrastructure/supabase_owner_venue_repository.dart';

/// Owner venue repository instance.
final ownerVenueRepositoryProvider = Provider<OwnerVenueRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseOwnerVenueRepository(client);
});

/// List of venues owned by the current owner.
final myVenuesProvider = FutureProvider<List<Venue>>((ref) {
  return ref.watch(ownerVenueRepositoryProvider).myVenues();
});

/// Create a venue and invalidate the list.
final createVenueProvider = FutureProvider.autoDispose
    .family<Venue, ({
      String name,
      String categoryId,
      String description,
      String city,
      String state,
      double latitude,
      double longitude,
      int capacity,
      double pricingBaseAmount,
      String? address,
      String? pincode,
      List<VenueImage>? images,
      List<String>? facilities,
      String? videoUrl,
      String? tour3dUrl,
    })>((ref, params) async {
  final repo = ref.watch(ownerVenueRepositoryProvider);
  final venue = await repo.createVenue(
    name: params.name,
    categoryId: params.categoryId,
    description: params.description,
    city: params.city,
    state: params.state,
    latitude: params.latitude,
    longitude: params.longitude,
    capacity: params.capacity,
    pricingBaseAmount: params.pricingBaseAmount,
    address: params.address,
    pincode: params.pincode,
    images: params.images,
    facilities: params.facilities,
    videoUrl: params.videoUrl,
    tour3dUrl: params.tour3dUrl,
  );
  ref.invalidate(myVenuesProvider);
  return venue;
});

/// Update an existing venue and invalidate the list.
final updateVenueProvider = FutureProvider.autoDispose
    .family<Venue, ({
      String venueId,
      String? name,
      String? categoryId,
      String? description,
      String? city,
      String? state,
      double? latitude,
      double? longitude,
      int? capacity,
      double? pricingBaseAmount,
      bool? isActive,
      String? address,
      String? pincode,
      List<VenueImage>? images,
      List<String>? facilities,
      String? videoUrl,
      String? tour3dUrl,
    })>((ref, params) async {
  final repo = ref.watch(ownerVenueRepositoryProvider);
  final venue = await repo.updateVenue(
    venueId: params.venueId,
    name: params.name,
    categoryId: params.categoryId,
    description: params.description,
    city: params.city,
    state: params.state,
    latitude: params.latitude,
    longitude: params.longitude,
    capacity: params.capacity,
    pricingBaseAmount: params.pricingBaseAmount,
    isActive: params.isActive,
    address: params.address,
    pincode: params.pincode,
    images: params.images,
    facilities: params.facilities,
    videoUrl: params.videoUrl,
    tour3dUrl: params.tour3dUrl,
  );
  ref.invalidate(myVenuesProvider);
  return venue;
});

/// Delete a venue and invalidate the list.
final deleteVenueProvider = FutureProvider.autoDispose
    .family<void, String>((ref, venueId) async {
  final repo = ref.watch(ownerVenueRepositoryProvider);
  await repo.deleteVenue(venueId);
  ref.invalidate(myVenuesProvider);
});

