import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/cms_media_repository.dart';
import '../infrastructure/supabase_cms_media_repository.dart';

final cmsMediaRepositoryProvider = Provider<CmsMediaRepository>(
    (ref) => SupabaseCmsMediaRepository(ref.watch(supabaseProvider)));

final cmsMediaAssetsProvider = FutureProvider.autoDispose.family(
    (ref, String query) =>
        ref.watch(cmsMediaRepositoryProvider).list(query: query));
