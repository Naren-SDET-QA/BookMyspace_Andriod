import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/feature_flag.dart';
import '../infrastructure/supabase_feature_flag_repository.dart';
import 'module_manifests.dart';

final featureFlagRepositoryProvider = Provider((ref) {
  return SupabaseFeatureFlagRepository(ref.watch(supabaseProvider));
});

final featureFlagsProvider =
    FutureProvider<Map<String, FeatureFlag>>((ref) async {
  final rows = await ref.watch(featureFlagRepositoryProvider).listFlags();
  return {for (final flag in rows) flag.key: flag};
});

/// Returns backend state when available and a manifest default while the
/// configuration request is loading or unavailable. This fallback is only a
/// safe UI default; it never grants access or changes RLS behavior.
final moduleFlagProvider = Provider.family<FeatureFlag, String>((ref, id) {
  final manifest = moduleManifestFor(id);
  final fallback = manifest?.fallback() ??
      const FeatureFlag(
        key: '',
        enabled: false,
        platforms: <String>[],
        config: <String, dynamic>{},
      );
  final flags = ref.watch(featureFlagsProvider);
  return flags.maybeWhen(
    data: (items) => items[id] ?? fallback,
    orElse: () => fallback,
  );
});

/// Platform-aware module check for optional UI surfaces.
final moduleEnabledProvider = Provider.family<bool, String>((ref, id) {
  final platform = kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          _ => 'web',
        };
  return ref.watch(moduleFlagProvider(id)).enabledFor(platform);
});
