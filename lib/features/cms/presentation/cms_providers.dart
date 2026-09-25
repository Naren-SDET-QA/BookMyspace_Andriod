import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/cms_banner.dart';
import '../infrastructure/supabase_cms_repository.dart';

final cmsRepositoryProvider = Provider<SupabaseCmsRepository>((ref) {
  return SupabaseCmsRepository(ref.watch(supabaseProvider));
});

final activeCmsBannersProvider = FutureProvider<List<CmsBanner>>((ref) {
  return ref.watch(cmsRepositoryProvider).listActiveBanners();
});

final adminCmsBannersProvider = FutureProvider<List<CmsBanner>>((ref) {
  return ref.watch(cmsRepositoryProvider).listAllBannersForAdmin();
});

/// Active banners indexed by `slot`, for the category-image (and any
/// future slot-targeted) lookups. Banners with no slot (the generic offer
/// carousel) are excluded here -- same underlying fetch as
/// [activeCmsBannersProvider], just re-shaped, so this is not a second
/// data source.
final activeCmsBannersBySlotProvider = Provider<Map<String, CmsBanner>>((ref) {
  final banners = ref.watch(activeCmsBannersProvider).valueOrNull ?? const [];
  return {
    for (final b in banners)
      if (b.slot != null && b.slot!.isNotEmpty) b.slot!: b,
  };
});
