import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/presentation/module_providers.dart';
import '../domain/home_appearance.dart';

/// Feature-flag key holding the admin Home composition.
const homeAppearanceFlagKey = 'home_appearance';

/// Backend-driven Home composition.
///
/// Watches the plug-and-play flag system, so an admin change reaches every
/// platform without a new build. It never throws: while the config request is
/// loading, missing or malformed the shipped [HomeAppearance.defaults] render
/// instead, which keeps Home usable offline and in widget tests.
final homeAppearanceProvider = Provider<HomeAppearance>((ref) {
  final flag = ref.watch(moduleFlagProvider(homeAppearanceFlagKey));
  return HomeAppearance.fromJson(flag.config);
});

/// Blocks the customer should see, already filtered and ordered.
final homeVisibleBlocksProvider = Provider<List<HomeBlockConfig>>((ref) {
  return ref.watch(homeAppearanceProvider).visible;
});

/// Admin write path for the Home composition.
///
/// The UI never reports success before the backend confirms the write; a
/// rejected RLS/config write propagates to the caller.
class HomeAppearanceController {
  HomeAppearanceController(this._ref);

  final Ref _ref;

  Future<void> save(HomeAppearance appearance) async {
    final flag = _ref.read(moduleFlagProvider(homeAppearanceFlagKey));
    await _ref.read(featureFlagRepositoryProvider).saveFlag(
          key: homeAppearanceFlagKey,
          enabled: true,
          platforms: flag.platforms.isEmpty
              ? const ['ios', 'android', 'web']
              : flag.platforms,
          config: appearance.toJson(),
        );
    _ref.invalidate(featureFlagsProvider);
  }
}

final homeAppearanceControllerProvider =
    Provider<HomeAppearanceController>(HomeAppearanceController.new);
