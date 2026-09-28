import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../auth/presentation/auth_providers.dart';

/// Writes the hotel class (`venues.star_rating`, 1-5 or null). Venue RLS
/// limits the update to the owning organization.
class VenueStarRatingWriter {
  VenueStarRatingWriter(this._client);

  final SupabaseClient _client;

  Future<void> set(String venueId, int? stars) async {
    if (stars != null && (stars < 1 || stars > 5)) {
      throw const app_errors.ValidationException(
        'Hotel class must be between 1 and 5 stars.',
      );
    }
    try {
      await _client
          .from('venues')
          .update({'star_rating': stars}).eq('id', venueId);
    } on PostgrestException catch (e) {
      // Schemas without the column: nothing to store.
      if (e.code == '42703' || e.code == 'PGRST204') return;
      throw app_errors.mapError(e);
    }
  }
}

final venueStarRatingWriterProvider = Provider<VenueStarRatingWriter>(
  (ref) => VenueStarRatingWriter(ref.watch(supabaseProvider)),
);
