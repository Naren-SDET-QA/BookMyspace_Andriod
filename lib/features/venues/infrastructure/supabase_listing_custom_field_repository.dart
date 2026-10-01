import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/listing_custom_field.dart';

class SupabaseListingCustomFieldRepository
    implements ListingCustomFieldRepository {
  SupabaseListingCustomFieldRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ListingCustomField>> forVenue(String venueId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'list_venue_listing_fields',
      params: {'p_venue_id': venueId},
    );
    return rows
        .whereType<Map>()
        .map(
          (row) => ListingCustomField.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((field) => field.label.isNotEmpty)
        .toList(growable: false);
  }
}
