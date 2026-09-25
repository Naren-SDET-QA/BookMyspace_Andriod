import 'package:bookmyspace/core/widgets/test_id.dart';

import 'base_robot.dart';

/// Bottom-navigation destinations, by shell destination id.
abstract final class ShellTab {
  static const home = 'home';
  static const search = 'search';
  static const bookings = 'bookings';
  static const profile = 'profile';
}

class NavigationRobot extends BaseRobot {
  NavigationRobot(super.tester);

  Future<void> expectSignedInShell() async {
    await waitFor(E2eIds.nav(ShellTab.home));
    await waitFor(E2eIds.nav(ShellTab.profile));
  }

  Future<void> open(String tab) => tap(E2eIds.nav(tab));

  /// Pops pushed routes (venue, booking, checkout) until the bottom
  /// navigation is on top and can be tapped again.
  Future<void> returnToShell({int maxPops = 5}) async {
    final home = byId(E2eIds.nav(ShellTab.home)).hitTestable();
    for (var i = 0; i < maxPops && home.evaluate().isEmpty; i++) {
      await back();
    }
    await waitFor(E2eIds.nav(ShellTab.home));
  }
}
