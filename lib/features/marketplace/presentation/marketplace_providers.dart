import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/marketplace_catalog.dart';
import '../infrastructure/supabase_marketplace_repository.dart';

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return SupabaseMarketplaceRepository(
    ref.watch(supabaseProvider),
    platform: kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.iOS => 'ios',
            TargetPlatform.android => 'android',
            _ => 'web',
          },
  );
});

final marketplaceResultsProvider = FutureProvider.autoDispose
    .family<List<MarketplaceItem>, MarketplaceQuery>((ref, query) {
      ref.watch(currentUserProvider);
      return ref.watch(marketplaceRepositoryProvider).search(query);
    });
