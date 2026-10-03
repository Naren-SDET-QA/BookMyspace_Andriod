import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../infrastructure/town_fallback_repository.dart';

final townFallbackRepositoryProvider = Provider<TownFallbackRepository>(
  (ref) => TownFallbackRepository(ref.watch(supabaseProvider)),
);

/// Nearby venues for a search whose text names a town with no venues.
/// Keyed by (search text, category slug). Null when the text is not a known
/// place or nothing exists up to the place's state.
final townFallbackProvider = FutureProvider.autoDispose
    .family<TownFallback?, ({String text, String? categorySlug})>((ref, key) {
      return ref
          .watch(townFallbackRepositoryProvider)
          .lookup(key.text, categorySlug: key.categorySlug);
    });
