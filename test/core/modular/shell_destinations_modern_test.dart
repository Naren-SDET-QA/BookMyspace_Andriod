import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/modular/shell_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nav style defaults to classic so existing behaviour is unchanged', () {
    expect(ShellNavStyle.fromSetting(null), ShellNavStyle.classic);
    expect(ShellNavStyle.fromSetting('classic'), ShellNavStyle.classic);
    expect(ShellNavStyle.fromSetting('anything'), ShellNavStyle.classic);
    expect(ShellNavStyle.fromSetting('modern'), ShellNavStyle.modern);
    expect(
      visibleShellDestinations(FeatureRegistry.defaults())
          .map((d) => d.id)
          .toList(),
      ['home', 'map', 'search', 'bookings', 'profile', 'saved'],
    );
  });

  test('modern style shows Home / Explore / Bookings / Chat / Profile', () {
    final visible = visibleShellDestinations(
      FeatureRegistry.defaults(),
      style: ShellNavStyle.modern,
    );
    expect(visible.map((d) => d.id).toList(), [
      'home',
      'search',
      'bookings',
      'chat',
      'profile',
    ]);
    expect(visible.map((d) => d.branchIndex).toList(), [
      0,
      2,
      3,
      chatShellBranchIndex,
      4,
    ]);
  });

  test('modern chat tab hides when the AI feature is disabled', () {
    final registry = FeatureRegistry.defaults()
      ..apply(FeatureId.ai, enabled: false);
    final visible = visibleShellDestinations(
      registry,
      style: ShellNavStyle.modern,
    );
    expect(visible.any((d) => d.id == 'chat'), isFalse);
  });
}
