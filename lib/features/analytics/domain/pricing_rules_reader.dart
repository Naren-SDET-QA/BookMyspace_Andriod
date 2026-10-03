import 'venue_optimizer.dart';

/// Read-only access to `pricing_rules` for the Venue Optimizer. Writing
/// rules is intentionally not offered: server-side dynamic pricing (B10) is
/// not active yet, so saved rules would not change booking prices.
abstract interface class PricingRulesReader {
  Future<List<PricingRuleSummary>> forVenues(Iterable<String> venueIds);
}
