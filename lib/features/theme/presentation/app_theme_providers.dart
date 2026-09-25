import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_config.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/app_theme_config_snapshot.dart';
import '../infrastructure/supabase_app_theme_repository.dart';

final appThemeRepositoryProvider = Provider<SupabaseAppThemeRepository>((ref) {
  return SupabaseAppThemeRepository(ref.watch(supabaseProvider));
});

/// Published theme for the customer app. A network, schema, or malformed-data
/// failure keeps the shipped theme instead of blocking customer navigation.
final publishedAppThemeConfigProvider = FutureProvider<AppThemeConfig>((
  ref,
) async {
  try {
    return await ref.watch(appThemeRepositoryProvider).getPublished();
  } catch (_) {
    return AppThemeConfig.defaults;
  }
});

/// Synchronous safe value consumed by [BookMySpaceApp].
final effectiveAppThemeConfigProvider = Provider<AppThemeConfig>((ref) {
  return ref.watch(publishedAppThemeConfigProvider).valueOrNull ??
      AppThemeConfig.defaults;
});

/// Full draft/published state for the administrator workspace.
final adminAppThemeConfigProvider = FutureProvider<AppThemeConfigSnapshot>((
  ref,
) {
  return ref.watch(appThemeRepositoryProvider).getAdminSnapshot();
});

class AppThemeConfigController {
  AppThemeConfigController(this._ref);

  final Ref _ref;

  Future<AppThemeConfigSnapshot> saveDraft(AppThemeConfig config) async {
    final result = await _ref
        .read(appThemeRepositoryProvider)
        .saveDraft(config);
    _ref.invalidate(adminAppThemeConfigProvider);
    return result;
  }

  Future<AppThemeConfigSnapshot> publish() async {
    final result = await _ref.read(appThemeRepositoryProvider).publish();
    _ref.invalidate(adminAppThemeConfigProvider);
    _ref.invalidate(publishedAppThemeConfigProvider);
    return result;
  }
}

final appThemeConfigControllerProvider = Provider<AppThemeConfigController>(
  AppThemeConfigController.new,
);
