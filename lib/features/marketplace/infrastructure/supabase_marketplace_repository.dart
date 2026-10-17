import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/marketplace_catalog.dart';

class SupabaseMarketplaceRepository implements MarketplaceRepository {
  const SupabaseMarketplaceRepository(this._client, {this.platform = 'web'});
  final SupabaseClient _client;
  final String platform;

  @override
  Future<List<MarketplaceItem>> search(MarketplaceQuery query) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'marketplace_search',
        params: {...query.toParams(), 'p_platform': platform},
      );
      return rows
          .map(
            (row) =>
                MarketplaceItem.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } catch (error) {
      throw app_errors.mapError(error);
    }
  }
}
