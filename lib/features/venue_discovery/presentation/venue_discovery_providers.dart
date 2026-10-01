import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/discovered_place.dart';
import '../infrastructure/nominatim_place_discovery_service.dart';
import '../infrastructure/supabase_discovery_repository.dart';

final discoveryRepositoryProvider = Provider<SupabaseDiscoveryRepository>((
  ref,
) {
  return SupabaseDiscoveryRepository(ref.watch(supabaseProvider));
});

/// Staging rows awaiting admin review (`venue_discovery_staging`,
/// status = PENDING_REVIEW). Populated both by this app's own search screen
/// and by anyone else calling the `import-venues` edge function.
final pendingDiscoveryStagingProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
      return ref.watch(discoveryRepositoryProvider).pendingReview();
    });

/// Owner-claim queue visible only to administrators through the table RLS.
final pendingVenueClaimsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(discoveryRepositoryProvider).pendingClaims();
});

final nominatimPlaceDiscoveryProvider =
    Provider<NominatimPlaceDiscoveryService>((ref) {
      final service = NominatimPlaceDiscoveryService();
      ref.onDispose(service.close);
      return service;
    });

/// External place results are read-only and are always kept separate from
/// bookable venue results at the provider boundary.
final externalPlaceSearchProvider = FutureProvider.autoDispose
    .family<List<DiscoveredPlace>, String>((ref, query) {
      return ref.watch(nominatimPlaceDiscoveryProvider).search(query);
    });
