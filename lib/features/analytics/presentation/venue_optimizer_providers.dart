import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../owner_venues/presentation/providers/owner_venue_providers.dart';
import '../domain/pricing_rules_reader.dart';
import '../domain/venue_optimizer.dart';
import '../infrastructure/supabase_pricing_rules_reader.dart';

final pricingRulesReaderProvider = Provider<PricingRulesReader>(
  (ref) => SupabasePricingRulesReader(ref.watch(supabaseProvider)),
);

/// One venue's active slots and blocked dates, via the existing owner
/// venue repository (two reads per venue, cached while the screen is open).
final venueCapacityProvider = FutureProvider.autoDispose
    .family<VenueCapacity, String>((ref, venueId) async {
      final repo = ref.watch(ownerVenueRepositoryProvider);
      final (slots, blocked) = await (
        repo.listTimeSlots(venueId),
        repo.listBlockedDates(venueId),
      ).wait;
      return VenueCapacity(
        venueId: venueId,
        slots: slots,
        blockedDates: {
          for (final b in blocked)
            DateTime(b.date.year, b.date.month, b.date.day),
        },
      );
    });

/// Capacity for every venue the signed-in owner manages. Independent of the
/// analytics date range, so changing the range does not refetch it.
final ownerCapacityProvider = FutureProvider.autoDispose<List<VenueCapacity>>((
  ref,
) async {
  final venues = await ref.watch(myVenuesProvider.future);
  return Future.wait([
    for (final v in venues) ref.watch(venueCapacityProvider(v.id).future),
  ]);
});

/// Pricing rules for the owner's venues, read-only.
final ownerPricingRulesProvider =
    FutureProvider.autoDispose<List<PricingRuleSummary>>((ref) async {
      final venues = await ref.watch(myVenuesProvider.future);
      return ref
          .watch(pricingRulesReaderProvider)
          .forVenues(venues.map((v) => v.id));
    });
