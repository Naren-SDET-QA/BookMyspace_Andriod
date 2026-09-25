import 'feature_id.dart';
import 'feature_registry.dart';

/// One bottom-nav item. [feature] is null for destinations that always stay.
class ShellDestination {
  const ShellDestination({
    required this.branchIndex,
    required this.id,
    this.feature,
  });

  final int branchIndex;
  final String id;
  final FeatureId? feature;
}

// Primary bottom-nav destinations, aligned with the Android reference
// app's bottom bar: Home / Map / Search / Bookings / Profile / Saved.
// Notifications and Courses are reachable as standalone pushed routes from
// Home (and elsewhere) instead of occupying a tab -- matching how the
// Android app treats them as secondary, not primary, destinations.
const shellDestinationCatalog = [
  ShellDestination(branchIndex: 0, id: 'home'),
  ShellDestination(branchIndex: 1, id: 'map', feature: FeatureId.maps),
  ShellDestination(branchIndex: 2, id: 'search', feature: FeatureId.search),
  ShellDestination(branchIndex: 3, id: 'bookings', feature: FeatureId.booking),
  ShellDestination(branchIndex: 4, id: 'profile'),
  ShellDestination(branchIndex: 5, id: 'saved'),
];

/// Admin-selectable bottom-nav style (Admin settings -> Home UI ->
/// `bottom_nav_style`). `classic` (default, unchanged) is the original 6-tab
/// bar above; `modern` is the optional 5-tab Home / Explore / Bookings /
/// Chat / Profile bar that goes with the modern Home page. Map and Saved
/// stay reachable as routes in both styles.
enum ShellNavStyle {
  modern,
  classic;

  static ShellNavStyle fromSetting(Object? value) =>
      value?.toString() == 'modern' ? ShellNavStyle.modern : ShellNavStyle.classic;
}

/// Branch index of the Chat (AI assistant) shell branch.
const chatShellBranchIndex = 6;

const modernShellDestinationCatalog = [
  ShellDestination(branchIndex: 0, id: 'home'),
  ShellDestination(branchIndex: 2, id: 'search', feature: FeatureId.search),
  ShellDestination(branchIndex: 3, id: 'bookings', feature: FeatureId.booking),
  ShellDestination(
    branchIndex: chatShellBranchIndex,
    id: 'chat',
    feature: FeatureId.ai,
  ),
  ShellDestination(branchIndex: 4, id: 'profile'),
];

List<ShellDestination> visibleShellDestinations(
  FeatureRegistry registry, {
  ShellNavStyle style = ShellNavStyle.classic,
}) {
  final catalog = style == ShellNavStyle.modern
      ? modernShellDestinationCatalog
      : shellDestinationCatalog;
  return catalog
      .where(
        (item) =>
            item.feature == null ||
            (registry.isExposed(item.feature!) &&
                (registry.configOf(item.feature!).config['navigation_visible']
                        as bool? ??
                    true)),
      )
      .toList(growable: false);
}

int selectedShellIndex({
  required int currentBranch,
  required List<ShellDestination> visible,
}) {
  final index = visible.indexWhere((item) => item.branchIndex == currentBranch);
  return index < 0 ? 0 : index;
}
