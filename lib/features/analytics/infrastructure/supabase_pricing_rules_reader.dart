import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/pricing_rules_reader.dart';
import '../domain/venue_optimizer.dart';

class SupabasePricingRulesReader implements PricingRulesReader {
  SupabasePricingRulesReader(this._client);
  final SupabaseClient _client;

  @override
  Future<List<PricingRuleSummary>> forVenues(Iterable<String> venueIds) async {
    final ids = venueIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];
    try {
      // `select('*')` keeps this working on both the B10 schema and the
      // older multiplier-only one.
      final rows = await _client
          .from('pricing_rules')
          .select('*')
          .inFilter('venue_id', ids);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PricingRuleSummary.fromJson)
          .toList(growable: false);
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }
}
