import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../modules/presentation/module_providers.dart';
import '../domain/nav_tabs.dart';

/// Feature-flag key holding the admin bottom-bar composition.
const navTabsFlagKey = 'nav_tabs';

/// Backend-driven bottom navigation.
///
/// Never throws: while the config request is loading, missing or malformed the
/// shipped [NavTabsConfig.defaults] render instead, which keeps the shell usable
/// offline and in widget tests.
final navTabsProvider = Provider<NavTabsConfig>((ref) {
  final flag = ref.watch(moduleFlagProvider(navTabsFlagKey));
  return NavTabsConfig.fromJson(flag.config);
});

/// Destinations the bar should render, already filtered and ordered.
///
/// A bar with zero destinations would leave the shell unusable, so an
/// over-eager config falls back to the shipped set rather than rendering an
/// empty navigation.
final visibleNavTabsProvider = Provider<List<NavTabConfig>>((ref) {
  final visible = ref.watch(navTabsProvider).visible;
  return visible.isEmpty ? NavTabsConfig.defaults.visible : visible;
});

/// Admin write path for the bottom navigation.
///
/// The UI never reports success before the backend confirms the write.
class NavTabsController {
  NavTabsController(this._ref);

  final Ref _ref;

  Future<void> save(NavTabsConfig config) async {
    final flag = _ref.read(moduleFlagProvider(navTabsFlagKey));
    await _ref.read(featureFlagRepositoryProvider).saveFlag(
          key: navTabsFlagKey,
          enabled: true,
          platforms: flag.platforms.isEmpty
              ? const ['ios', 'android', 'web']
              : flag.platforms,
          config: config.toJson(),
        );
    _ref.invalidate(featureFlagsProvider);
  }
}

final navTabsControllerProvider =
    Provider<NavTabsController>(NavTabsController.new);
