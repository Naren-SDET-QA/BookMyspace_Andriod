import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/saved_item.dart';
import '../infrastructure/supabase_saved_items_repository.dart';

final savedItemsRepositoryProvider = Provider<SavedItemsRepository>((ref) {
  return SupabaseSavedItemsRepository(ref.watch(supabaseProvider));
});

/// Ids of saved courses and institutes for the signed-in user.
final savedItemIdsProvider =
    FutureProvider<Map<SavedItemType, Set<String>>>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const {};
  return ref.watch(savedItemsRepositoryProvider).savedIds();
});

final savedListingsProvider =
    FutureProvider.family<List<SavedListing>, SavedItemType>((ref, type) async {
  if (ref.watch(currentUserProvider) == null) return const [];
  // Refetch whenever the saved set changes.
  await ref.watch(savedItemIdsProvider.future);
  return ref.watch(savedItemsRepositoryProvider).listings(type);
});

/// Save / unsave. Do not watch from build().
class SavedItemsController {
  SavedItemsController(this._ref);

  final Ref _ref;

  Future<void> toggle(SavedItemType type, String id, {required bool saved}) async {
    final repo = _ref.read(savedItemsRepositoryProvider);
    if (saved) {
      await repo.unsave(type, id);
    } else {
      await repo.save(type, id);
    }
    _ref.invalidate(savedItemIdsProvider);
  }
}

final savedItemsControllerProvider =
    Provider<SavedItemsController>((ref) => SavedItemsController(ref));
