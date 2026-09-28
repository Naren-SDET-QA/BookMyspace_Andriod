import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/listing_custom_field.dart';
import '../infrastructure/supabase_listing_custom_field_repository.dart';

final listingCustomFieldRepositoryProvider =
    Provider<ListingCustomFieldRepository>(
      (ref) =>
          SupabaseListingCustomFieldRepository(ref.watch(supabaseProvider)),
    );

final venueListingCustomFieldsProvider = FutureProvider.autoDispose
    .family<List<ListingCustomField>, String>((ref, venueId) {
      return ref.watch(listingCustomFieldRepositoryProvider).forVenue(venueId);
    });
