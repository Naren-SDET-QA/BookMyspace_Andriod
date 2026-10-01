import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/platform_status.dart';
import 'admin_settings_providers.dart';

/// Current maintenance / broadcast state. Never throws: any failure (no
/// network, older schema) reads as "no maintenance, no banner"; the server
/// still refuses bookings while maintenance is on.
final platformStatusProvider = FutureProvider<PlatformStatus>((ref) async {
  try {
    final row = await ref
        .watch(supabaseProvider)
        .from('module_feature_configs')
        .select('metadata')
        .eq('module_key', PlatformStatus.moduleKey)
        .isFilter('venue_id', null)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final metadata = row?['metadata'];
    return metadata is Map
        ? PlatformStatus.fromMetadata(Map<String, dynamic>.from(metadata))
        : PlatformStatus.none;
  } catch (_) {
    return PlatformStatus.none;
  }
});

/// Admin save. Do not watch from build().
class PlatformStatusController {
  PlatformStatusController(this._ref);

  final Ref _ref;

  Future<void> save(PlatformStatus status) async {
    await _ref
        .read(adminSettingsRepositoryProvider)
        .saveSection(PlatformStatus.moduleKey, status.toMetadata());
    _ref.invalidate(platformStatusProvider);
  }
}

final platformStatusControllerProvider = Provider<PlatformStatusController>(
  (ref) => PlatformStatusController(ref),
);
