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
